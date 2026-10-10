using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Maester.Engine
{
    /// <summary>
    /// The panels of the dashboard: a column to the right of the main content on wide consoles, and the
    /// results chart under the lanes. The caller chooses the panels and their order with SetPanels.
    ///
    /// Text panels (Tenant, Blog, Version, or any other name) show the lines the caller gives them. The live
    /// panels are worked out here from the results as they arrive: Failed (by severity), Pace (and the slowest
    /// tests), Drift (against the results of an earlier run), Tips (one at a time) and Results (one square per
    /// test, in the main column).
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const int MainWidth = 98;
        private const int PaneGap = 3;
        private const int MinPaneWidth = 38;
        private const int MaxPaneWidth = 58;
        private const string ResultsPanel = "Results";
        private static readonly string[] SeverityOrder = { "Critical", "High", "Medium", "Low" };
        private static readonly string[] SeverityColor = { "31", "38;5;208", "33", "2" };
        private static readonly char[] Spark = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' };
        private static readonly char[] Eighths = { '▏', '▎', '▍', '▌', '▋', '▊', '▉' };

        private sealed class TextPanel
        {
            public string Title;
            public string[] Lines;
        }

        private sealed class Slow
        {
            public string Id;
            public string Title;
            public TimeSpan Duration;
        }

        private readonly List<string> _panels = new List<string>();
        private readonly Dictionary<string, TextPanel> _text = new Dictionary<string, TextPanel>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, int> _failedBySeverity = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        private readonly List<string> _sequence = new List<string>();
        private readonly List<double> _finishSeconds = new List<double>();
        private readonly List<Slow> _slowest = new List<Slow>();
        private readonly Dictionary<string, string> _finished = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        private readonly List<string> _newlyFailing = new List<string>();
        private readonly System.Diagnostics.Stopwatch _runClock = new System.Diagnostics.Stopwatch();
        private string[] _tips = new string[0];
        private Dictionary<string, string> _baseline;
        private string _baselineLabel;
        private int _fixedCount;
        private int _newTests;

        /// <summary>
        /// The panels to show, in order. "Results" is the chart in the main column; the others stack in the right
        /// column. A panel with nothing to show is left out.
        /// </summary>
        public void SetPanels(string[] names)
        {
            lock (_gate)
            {
                _panels.Clear();
                if (names != null)
                {
                    foreach (var n in names)
                    {
                        if (!string.IsNullOrWhiteSpace(n) && !_panels.Contains(n)) _panels.Add(n.Trim());
                    }
                }
                Redraw();
            }
        }

        /// <summary>The content of a text panel. The lines may contain colour. Null or no lines removes the panel.</summary>
        public void SetPanelText(string name, string title, string[] lines)
        {
            if (string.IsNullOrEmpty(name)) return;
            lock (_gate)
            {
                if (lines == null || lines.Length == 0) _text.Remove(name);
                else _text[name] = new TextPanel { Title = title, Lines = lines };
                Redraw();
            }
        }

        /// <summary>The tips of the Tips panel. One is shown at a time, for about twelve seconds each.</summary>
        public void SetTips(string[] tips)
        {
            lock (_gate)
            {
                _tips = tips ?? new string[0];
                Redraw();
            }
        }

        /// <summary>The results of an earlier run (test ID to result) that the Drift panel compares with, and when it ran.</summary>
        public void SetBaseline(IDictionary<string, string> results, string label)
        {
            lock (_gate)
            {
                _baseline = results == null ? null : new Dictionary<string, string>(results, StringComparer.OrdinalIgnoreCase);
                _baselineLabel = label;
                RecountDrift();
                Redraw();
            }
        }

        /// <summary>
        /// Reads an earlier Maester results file on a background thread and makes it the baseline of the Drift
        /// panel. A file from another tenant, or one that cannot be read, is ignored.
        /// </summary>
        public Task LoadBaselineAsync(string path, string tenantId)
        {
            return Task.Run(() =>
            {
                try
                {
                    var results = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    string label = null;
                    using (var doc = JsonDocument.Parse(File.ReadAllBytes(path)))
                    {
                        var root = doc.RootElement;
                        string fileTenant = ReadString(root, "TenantId");
                        bool otherTenant = !string.IsNullOrEmpty(tenantId) && !string.IsNullOrEmpty(fileTenant) &&
                            !string.Equals(tenantId, fileTenant, StringComparison.OrdinalIgnoreCase);
                        if (otherTenant) return;
                        DateTime when;
                        if (DateTime.TryParse(ReadString(root, "ExecutedAt"), CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out when))
                        {
                            label = when.ToString("MMM d, HH:mm", CultureInfo.InvariantCulture);
                        }
                        JsonElement tests;
                        if (!root.TryGetProperty("Tests", out tests) || tests.ValueKind != JsonValueKind.Array) return;
                        foreach (var t in tests.EnumerateArray())
                        {
                            string id = ReadString(t, "Id");
                            string result = ReadString(t, "Result");
                            if (!string.IsNullOrEmpty(id) && !string.IsNullOrEmpty(result)) results[id] = result;
                        }
                    }
                    if (results.Count > 0) SetBaseline(results, label);
                }
                catch (Exception)
                {
                    // An unreadable or half-written results file only means there is no Drift panel.
                }
            });
        }

        private static string ReadString(JsonElement element, string name)
        {
            JsonElement value;
            if (element.ValueKind != JsonValueKind.Object || !element.TryGetProperty(name, out value)) return null;
            return value.ValueKind == JsonValueKind.String ? value.GetString() : null;
        }

        // ------------------------------------------------------------------ recording results (callers hold _gate)

        private void ResetPanelState()
        {
            _failedBySeverity.Clear();
            _sequence.Clear();
            _finishSeconds.Clear();
            _slowest.Clear();
            _finished.Clear();
            RecountDrift();
            _runClock.Restart();
        }

        private void RecordFinished(string id, string title, string result, string severity, TimeSpan duration)
        {
            _sequence.Add(result);
            _finishSeconds.Add(_runClock.Elapsed.TotalSeconds);
            if (result == "Failed")
            {
                string key = Array.IndexOf(SeverityOrder, Normalise(severity)) >= 0 ? Normalise(severity) : "Low";
                int count;
                _failedBySeverity.TryGetValue(key, out count);
                _failedBySeverity[key] = count + 1;
            }
            if (!string.IsNullOrEmpty(id))
            {
                _slowest.Add(new Slow { Id = id, Title = title, Duration = duration });
                _slowest.Sort((a, b) => b.Duration.CompareTo(a.Duration));
                if (_slowest.Count > 3) _slowest.RemoveAt(3);
                _finished[id] = result;
                CountDrift(id, result);
            }
        }

        private static string Normalise(string severity)
        {
            if (string.IsNullOrEmpty(severity)) return string.Empty;
            foreach (var s in SeverityOrder)
            {
                if (string.Equals(s, severity, StringComparison.OrdinalIgnoreCase)) return s;
            }
            return severity;
        }

        private void RecountDrift()
        {
            _newlyFailing.Clear();
            _fixedCount = 0;
            _newTests = 0;
            if (_baseline == null) return;
            foreach (var kv in _finished) CountDrift(kv.Key, kv.Value);
        }

        private void CountDrift(string id, string result)
        {
            if (_baseline == null) return;
            string before;
            if (!_baseline.TryGetValue(id, out before))
            {
                _newTests++;
                return;
            }
            if (result == "Failed" && before == "Passed") _newlyFailing.Add(id);
            else if (result == "Passed" && before == "Failed") _fixedCount++;
        }

        // ------------------------------------------------------------------ layout

        /// <summary>The width of the right column for a console width, or 0 when there is no room or nothing to show in it.</summary>
        private int PaneWidth(int width)
        {
            bool any = false;
            foreach (var p in _panels)
            {
                if (!string.Equals(p, ResultsPanel, StringComparison.OrdinalIgnoreCase)) any = true;
            }
            if (!any) return 0;
            int pane = Math.Min(MaxPaneWidth, width - 1 - MainWidth - PaneGap);
            return pane >= MinPaneWidth ? pane : 0;
        }

        private bool PanelShown(string name)
        {
            foreach (var p in _panels)
            {
                if (string.Equals(p, name, StringComparison.OrdinalIgnoreCase)) return true;
            }
            return false;
        }

        /// <summary>The right column: the panels that have something to show and fit in the rows, in order.</summary>
        private List<Line> BuildPane(int paneWidth, int rows, bool ansi)
        {
            var pane = new List<Line>();
            foreach (var name in _panels)
            {
                if (string.Equals(name, ResultsPanel, StringComparison.OrdinalIgnoreCase)) continue;
                var panel = BuildPanel(name, paneWidth, ansi);
                if (panel == null || panel.Count == 0) continue;
                int needed = panel.Count + (pane.Count > 0 ? 1 : 0);
                if (pane.Count + needed > rows) continue;
                if (pane.Count > 0) pane.Add(new Line { Text = string.Empty, Plain = string.Empty });
                pane.AddRange(panel);
            }
            return pane;
        }

        private List<Line> BuildPanel(string name, int width, bool ansi)
        {
            switch (name.ToLowerInvariant())
            {
                case "failed":
                    return BuildFailedPanel(width, ansi);
                case "pace":
                    return BuildPacePanel(width, ansi);
                case "drift":
                    return BuildDriftPanel(width, ansi);
                case "tips":
                    return BuildTipsPanel(width, ansi);
                default:
                    return BuildTextPanel(name, width, ansi);
            }
        }

        private Line Title(string title, string right, int width, bool ansi)
        {
            var b = new LineBuilder(ansi).Add(title, "1");
            if (!string.IsNullOrEmpty(right) && title.Length + right.Length + 2 <= width)
            {
                b.Add(new string(' ', width - title.Length - right.Length)).Add(right, "2");
            }
            return Truncate(b.Build(), width, ansi);
        }

        private List<Line> BuildTextPanel(string name, int width, bool ansi)
        {
            TextPanel panel;
            if (!_text.TryGetValue(name, out panel)) return null;
            var lines = new List<Line> { Title(panel.Title ?? name, null, width, ansi) };
            foreach (var raw in panel.Lines)
            {
                string plain = " " + StripAnsi(raw);
                lines.Add(plain.Length <= width
                    ? new Line { Text = " " + (ansi ? raw : StripAnsi(raw)), Plain = plain }
                    : Truncate(new Line { Text = plain, Plain = plain }, width, ansi));
            }
            return lines;
        }

        private List<Line> BuildFailedPanel(int width, bool ansi)
        {
            if (!_running && _sequence.Count == 0) return null;
            int max = 1;
            foreach (var s in SeverityOrder)
            {
                int c;
                _failedBySeverity.TryGetValue(s, out c);
                max = Math.Max(max, c);
            }
            var lines = new List<Line> { Title("Failed so far", N(_failed), width, ansi) };
            int barWidth = Math.Max(4, width - 16);
            for (int i = 0; i < SeverityOrder.Length; i++)
            {
                int count;
                _failedBySeverity.TryGetValue(SeverityOrder[i], out count);
                var b = new LineBuilder(ansi).Add(" " + SeverityOrder[i].PadRight(9), count > 0 ? null : "2");
                string bar = Bar((double)count / max * barWidth);
                b.Add(bar, SeverityColor[i]).Add(new string(' ', barWidth - bar.Length + 1)).Add(N(count).PadLeft(4), count > 0 ? SeverityColor[i] : "2");
                lines.Add(Truncate(b.Build(), width, ansi));
            }
            return lines;
        }

        /// <summary>A horizontal bar of a fractional number of cells.</summary>
        private string Bar(double cells)
        {
            int full = (int)Math.Floor(cells);
            var sb = new StringBuilder(new string(Unicode ? '█' : '#', full));
            int part = (int)Math.Floor((cells - full) * 8);
            if (Unicode && part > 0) sb.Append(Eighths[part - 1]);
            else if (!Unicode && cells > 0 && full == 0) sb.Append('#');
            return sb.ToString();
        }

        private List<Line> BuildPacePanel(int width, bool ansi)
        {
            if (_finishSeconds.Count == 0) return null;
            double elapsed = Math.Max(0.001, _running ? _runClock.Elapsed.TotalSeconds : _finishSeconds[_finishSeconds.Count - 1]);
            string rate = (_finishSeconds.Count / elapsed).ToString("0.0", CultureInfo.InvariantCulture) + " tests/s";
            var lines = new List<Line> { Title("Pace", rate, width, ansi) };

            // Tests finished in each slice of the run so far.
            int buckets = Math.Max(8, Math.Min(40, width - 2));
            var counts = new int[buckets];
            int top = 1;
            foreach (var t in _finishSeconds)
            {
                int index = Math.Min(buckets - 1, (int)(t / elapsed * buckets));
                counts[index]++;
                top = Math.Max(top, counts[index]);
            }
            var spark = new StringBuilder();
            foreach (var c in counts)
            {
                if (Unicode) spark.Append(c == 0 ? ' ' : Spark[Math.Min(Spark.Length - 1, (int)((double)c / top * (Spark.Length - 1)))]);
                else spark.Append(c == 0 ? ' ' : (c * 2 > top ? '#' : '-'));
            }
            lines.Add(new LineBuilder(ansi).Add(" ").Add(spark.ToString(), "36").Build());

            if (_slowest.Count > 0)
            {
                lines.Add(new LineBuilder(ansi).Add(" Slowest so far", "2").Build());
                foreach (var s in _slowest)
                {
                    string time = Short(s.Duration).PadLeft(7);
                    var left = Truncate(new LineBuilder(ansi).Add(" " + (s.Id ?? string.Empty).PadRight(16) + " ").Add(s.Title, "2").Build(), width - time.Length, ansi);
                    string gap = new string(' ', Math.Max(0, width - time.Length - left.Plain.Length));
                    lines.Add(new Line { Text = left.Text + gap + time, Plain = left.Plain + gap + time });
                }
            }
            return lines;
        }

        private List<Line> BuildDriftPanel(int width, bool ansi)
        {
            if (_baseline == null) return null;
            var lines = new List<Line> { Title("Since the last run", _baselineLabel, width, ansi) };
            if (_newlyFailing.Count == 0 && _fixedCount == 0 && _newTests == 0)
            {
                lines.Add(new LineBuilder(ansi).Add(_sequence.Count == 0 ? " Waiting for results" + Ellipsis() : " No changes so far", "2").Build());
                return lines;
            }
            if (_newlyFailing.Count > 0)
            {
                lines.Add(new LineBuilder(ansi).Add(" " + (Unicode ? "▲ " : "^ ") + N(_newlyFailing.Count) + " newly failing", "31").Build());
                lines.Add(Truncate(new LineBuilder(ansi).Add("   " + string.Join(Unicode ? " · " : ", ", _newlyFailing), "2").Build(), width, ansi));
            }
            if (_fixedCount > 0) lines.Add(new LineBuilder(ansi).Add(" " + (Unicode ? "▼ " : "v ") + N(_fixedCount) + " fixed", "32").Build());
            if (_newTests > 0) lines.Add(new LineBuilder(ansi).Add(" + " + N(_newTests) + " new test" + (_newTests == 1 ? string.Empty : "s"), "36").Build());
            return lines;
        }

        private List<Line> BuildTipsPanel(int width, bool ansi)
        {
            if (_tips.Length == 0) return null;
            string tip = _tips[(int)(_clock.Elapsed.TotalSeconds / 12) % _tips.Length];
            var lines = new List<Line> { Title("Tip", null, width, ansi) };
            foreach (var wrapped in Wrap(tip, width - 1)) lines.Add(new LineBuilder(ansi).Add(" " + wrapped, "2").Build());
            return lines;
        }

        /// <summary>Breaks text at spaces into lines of at most <paramref name="width"/> characters.</summary>
        private static List<string> Wrap(string text, int width)
        {
            var lines = new List<string>();
            var current = new StringBuilder();
            foreach (var word in (text ?? string.Empty).Split(' '))
            {
                if (current.Length > 0 && current.Length + 1 + word.Length > width)
                {
                    lines.Add(current.ToString());
                    current.Clear();
                }
                if (current.Length > 0) current.Append(' ');
                current.Append(word);
            }
            if (current.Length > 0) lines.Add(current.ToString());
            return lines;
        }

        /// <summary>
        /// The results chart of the main column: one square per test (or per group of tests when there are more
        /// than fit), filled in the order the tests finish and coloured by the worst result in the square.
        /// </summary>
        private List<Line> BuildResultsChart(int width, int maxRows, bool ansi)
        {
            var lines = new List<Line>();
            if (_total <= 0 || maxRows < 1 || !PanelShown(ResultsPanel)) return lines;
            int columns = Math.Max(10, Math.Min(48, (width - 2) / 2));
            int rows = Math.Min(6, maxRows);
            int perSquare = Math.Max(1, (int)Math.Ceiling((double)_total / (columns * rows)));
            int squares = (int)Math.Ceiling((double)_total / perSquare);
            bool caption = perSquare > 1 && maxRows > (int)Math.Ceiling((double)squares / columns);
            string mark = Unicode ? "■" : "#";

            LineBuilder row = null;
            for (int i = 0; i < squares; i++)
            {
                if (i % columns == 0)
                {
                    if (row != null) lines.Add(row.Build());
                    row = new LineBuilder(ansi).Add(" ");
                }
                int first = i * perSquare;
                int last = Math.Min(_total, first + perSquare);
                string colour = "38;5;238";
                string shown = ansi ? mark : (Unicode ? "□" : ".");
                if (first < _sequence.Count)
                {
                    colour = SquareColour(first, Math.Min(last, _sequence.Count));
                    shown = mark;
                }
                row.Add(shown, colour).Add(" ");
            }
            if (row != null) lines.Add(row.Build());
            if (caption) lines.Add(new LineBuilder(ansi).Add(" each square is " + N(perSquare) + " tests", "2").Build());
            return lines;
        }

        /// <summary>The colour of the worst result among the finished tests of a square.</summary>
        private string SquareColour(int first, int end)
        {
            int worst = 0;
            for (int i = first; i < end; i++)
            {
                int rank;
                switch (_sequence[i])
                {
                    case "Failed":
                        rank = 4;
                        break;
                    case "Error":
                        rank = 3;
                        break;
                    case "Investigate":
                        rank = 2;
                        break;
                    case "Passed":
                        rank = 1;
                        break;
                    default:
                        rank = 0;
                        break;
                }
                worst = Math.Max(worst, rank);
            }
            switch (worst)
            {
                case 4:
                    return "31";
                case 3:
                    return "33";
                case 2:
                    return "35";
                case 1:
                    return "32";
                default:
                    return "2";
            }
        }

        /// <summary>Puts the right column next to the main column, row by row.</summary>
        private static List<Line> Beside(List<Line> main, List<Line> pane, int mainWidth, int rows)
        {
            var screen = new List<Line>();
            int count = Math.Min(rows, Math.Max(main.Count, pane.Count));
            for (int i = 0; i < count; i++)
            {
                var left = i < main.Count ? main[i] : new Line { Text = string.Empty, Plain = string.Empty };
                if (i >= pane.Count || pane[i].Plain.Length == 0)
                {
                    screen.Add(left);
                    continue;
                }
                string gap = new string(' ', Math.Max(1, mainWidth + PaneGap - left.Plain.Length));
                screen.Add(new Line { Text = left.Text + gap + pane[i].Text, Plain = left.Plain + gap + pane[i].Plain });
            }
            return screen;
        }
    }
}
