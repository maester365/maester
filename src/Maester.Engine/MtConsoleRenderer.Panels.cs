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
        private const int StandardPaneWidth = 58;
        private const int MaxPaneWidth = 90;
        private const int SlowestShown = 3;
        private const int SlowestKept = 10;
        private const string ResultsPanel = "Results";
        private static readonly string[] SeverityOrder = { "Critical", "High", "Medium", "Low" };
        private static readonly string[] SeverityColor = { "31", "38;5;208", "33", "2" };
        private static readonly char[] Spark = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' };
        private static readonly char[] Eighths = { '▏', '▎', '▍', '▌', '▋', '▊', '▉' };

        private sealed class TextPanel
        {
            public string Title;
            public string[] Lines;
            public string Colour;
        }

        private sealed class TenantInfo
        {
            public string Name;
            public string Domain;
            public string Detail;
            public string[] Labels;
            public string[] Values;
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
        private TenantInfo _tenant;
        private MtBlogPost _blogPost;
        private string[] _tips = new string[0];
        private string[] _tipLinks = new string[0];
        private Dictionary<string, string> _baseline;
        private string _baselineLabel;
        private DateTime? _baselineWhen;
        private int _fixedCount;
        private int _newTests;
        private int _slowestShown = SlowestShown;

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
            SetPanelText(name, title, lines, null);
        }

        /// <summary>The content of a text panel, with the SGR colour of its border (for example "38;5;215" to draw attention).</summary>
        public void SetPanelText(string name, string title, string[] lines, string borderColour)
        {
            if (string.IsNullOrEmpty(name)) return;
            lock (_gate)
            {
                if (lines == null || lines.Length == 0) _text.Remove(name);
                else _text[name] = new TextPanel { Title = title, Lines = lines, Colour = borderColour };
                Redraw();
            }
        }

        /// <summary>
        /// The Tenant panel: the name on the left of the first line and the primary domain on its right, a line
        /// of detail (the account), and the counts (label and value, such as "Users" and "1.2K") in columns.
        /// </summary>
        public void SetTenant(string name, string domain, string detail, string[] labels, string[] values)
        {
            lock (_gate)
            {
                _tenant = new TenantInfo { Name = name, Domain = domain, Detail = detail, Labels = labels ?? new string[0], Values = values ?? new string[0] };
                Redraw();
            }
        }

        /// <summary>The Blog panel: the newest post, its title a hyperlink over at most two lines, its date in the border.</summary>
        public void SetBlogPost(MtBlogPost post)
        {
            lock (_gate)
            {
                _blogPost = post;
                Redraw();
            }
        }

        /// <summary>The tips of the Tips panel. One is shown at a time, for about twelve seconds each.</summary>
        public void SetTips(string[] tips)
        {
            SetTips(tips, null);
        }

        /// <summary>
        /// The tips of the Tips panel, each with the address of a page that says more (or null). The address is
        /// shown under the tip, as a hyperlink where the terminal supports them.
        /// </summary>
        public void SetTips(string[] tips, string[] links)
        {
            lock (_gate)
            {
                _tips = tips ?? new string[0];
                _tipLinks = links ?? new string[0];
                Redraw();
            }
        }

        /// <summary>The results of an earlier run (test ID to result) that the Drift panel compares with, and when it ran.</summary>
        public void SetBaseline(IDictionary<string, string> results, string label)
        {
            SetBaseline(results, label, null);
        }

        /// <summary>
        /// The results of an earlier run and the local time it ran. The panel then shows how long ago that was
        /// ("4 days ago") in its border, and the date next to that run's counts.
        /// </summary>
        public void SetBaseline(IDictionary<string, string> results, DateTime executedAt)
        {
            SetBaseline(results, null, executedAt);
        }

        private void SetBaseline(IDictionary<string, string> results, string label, DateTime? executedAt)
        {
            lock (_gate)
            {
                _baseline = results == null ? null : new Dictionary<string, string>(results, StringComparer.OrdinalIgnoreCase);
                _baselineLabel = label;
                _baselineWhen = executedAt;
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
                    DateTime? executedAt = null;
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
                            executedAt = when;
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
                    if (results.Count > 0) SetBaseline(results, null, executedAt);
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
                if (_slowest.Count > SlowestKept) _slowest.RemoveAt(SlowestKept);
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

        /// <summary>
        /// The width of the right column for a console width, or 0 when there is no room or nothing to show in it.
        /// The main column gets its standard width first, then the right column up to its standard width; beyond
        /// that the extra is shared, two parts to the main column and one to the right column.
        /// </summary>
        private int PaneWidth(int width)
        {
            bool any = false;
            foreach (var p in _panels)
            {
                if (!string.Equals(p, ResultsPanel, StringComparison.OrdinalIgnoreCase)) any = true;
            }
            if (!any) return 0;
            int room = width - 1 - MainWidth - PaneGap;
            if (room < MinPaneWidth) return 0;
            return room <= StandardPaneWidth ? room : Math.Min(MaxPaneWidth, StandardPaneWidth + (room - StandardPaneWidth) / 3);
        }

        /// <summary>Whether the right column is on screen at the current width and has this panel in it.</summary>
        public bool HasPanel(string name)
        {
            lock (_gate)
            {
                return PanelShown(name) && PaneWidth(CurrentWidth()) > 0;
            }
        }

        private bool PanelShown(string name)
        {
            foreach (var p in _panels)
            {
                if (string.Equals(p, name, StringComparison.OrdinalIgnoreCase)) return true;
            }
            return false;
        }

        /// <summary>What a panel shows: its title, an optional badge for the top border, the colour of its border, and its lines.</summary>
        private sealed class PanelContent
        {
            public string Title;
            public string Badge;
            public string Colour;
            public List<Line> Lines = new List<Line>();
        }

        private const string NeutralBorder = "38;5;240";
        private const string Amber = "38;5;215";

        /// <summary>
        /// The right column: each panel that has something to show, in order, as a box with its title in the top
        /// border. The border takes the colour of the panel's state (red around failures, amber around drift).
        /// A panel that does not fit in the rows that are left is skipped.
        /// </summary>
        private List<Line> BuildPane(int paneWidth, int rows, bool ansi)
        {
            _slowestShown = SlowestShown;
            var pane = StackPanels(paneWidth, rows, ansi);
            // Rows that are left over go to the Pace panel, which then lists more of the slowest tests.
            int spare = rows - pane.Count;
            if (spare > 0 && _slowest.Count > SlowestShown && PanelShown("Pace"))
            {
                _slowestShown = Math.Min(_slowest.Count, SlowestShown + spare);
                pane = StackPanels(paneWidth, rows, ansi);
            }
            return pane;
        }

        private List<Line> StackPanels(int paneWidth, int rows, bool ansi)
        {
            var pane = new List<Line>();
            int inner = paneWidth - 4;
            foreach (var name in _panels)
            {
                if (string.Equals(name, ResultsPanel, StringComparison.OrdinalIgnoreCase)) continue;
                var panel = BuildPanel(name, inner, ansi);
                if (panel == null || panel.Lines.Count == 0) continue;
                if (pane.Count + panel.Lines.Count + 2 > rows) continue;
                pane.AddRange(Box(panel, paneWidth, ansi));
            }
            return pane;
        }

        /// <summary>Frames a panel: the title and badge in the top border, the lines padded between the sides.</summary>
        private List<Line> Box(PanelContent panel, int width, bool ansi)
        {
            string h = Unicode ? "─" : "-";
            string v = Unicode ? "│" : "|";
            string colour = panel.Colour ?? NeutralBorder;
            int inner = width - 4;
            var box = new List<Line>();

            string title = Fit(panel.Title ?? string.Empty, inner - 2);
            string badge = panel.Badge;
            if (!string.IsNullOrEmpty(badge) && title.Length + badge.Length + 8 > width) badge = null;
            var top = new LineBuilder(ansi).Add((Unicode ? "╭" : "+") + h + " ", colour).Add(title, "1").Add(" ", colour);
            int fill = width - top.Length - 1 - (badge == null ? 0 : badge.Length + 3);
            top.Add(Repeat(h, Math.Max(0, fill)), colour);
            if (badge != null) top.Add(" " + badge + " ", panel.Colour ?? "2").Add(h, colour);
            top.Add(Unicode ? "╮" : "+", colour);
            box.Add(top.Build());

            foreach (var raw in panel.Lines)
            {
                var line = Truncate(raw, inner, ansi);
                string pad = new string(' ', inner - line.Plain.Length);
                string left = ansi ? Esc + colour + "m" + v + Esc + "0m " : v + " ";
                string right = ansi ? " " + Esc + colour + "m" + v + Esc + "0m" : " " + v;
                box.Add(new Line { Text = left + line.Text + pad + right, Plain = v + " " + line.Plain + pad + " " + v });
            }
            box.Add(new LineBuilder(ansi).Add((Unicode ? "╰" : "+") + Repeat(h, width - 2) + (Unicode ? "╯" : "+"), colour).Build());
            return box;
        }

        private static string Repeat(string s, int count)
        {
            var sb = new StringBuilder(s.Length * Math.Max(0, count));
            for (int i = 0; i < count; i++) sb.Append(s);
            return sb.ToString();
        }

        private PanelContent BuildPanel(string name, int width, bool ansi)
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
                case "tenant":
                    return _tenant != null ? BuildTenantPanel(width, ansi) : BuildTextPanel(name, ansi);
                case "blog":
                    return _blogPost != null ? BuildBlogPanel(width, ansi) : BuildTextPanel(name, ansi);
                default:
                    return BuildTextPanel(name, ansi);
            }
        }

        private PanelContent BuildTextPanel(string name, bool ansi)
        {
            TextPanel text;
            if (!_text.TryGetValue(name, out text)) return null;
            var panel = new PanelContent { Title = text.Title ?? name, Colour = text.Colour };
            foreach (var raw in text.Lines)
            {
                string plain = StripAnsi(raw);
                panel.Lines.Add(new Line { Text = ansi ? raw : plain, Plain = plain });
            }
            return panel;
        }

        private PanelContent BuildTenantPanel(int width, bool ansi)
        {
            var panel = new PanelContent { Title = "Tenant" };
            string name = _tenant.Name ?? string.Empty;
            string domain = _tenant.Domain ?? string.Empty;
            // The domain keeps its place on the right; the name is cut when the two do not fit.
            if (domain.Length > 0 && width - domain.Length - 2 < 8) domain = string.Empty;
            int nameRoom = domain.Length > 0 ? width - domain.Length - 2 : width;
            if (name.Length > nameRoom) name = name.Substring(0, Math.Max(0, nameRoom - 1)) + (Unicode ? "…" : ".");
            if (name.Length > 0 || domain.Length > 0)
            {
                panel.Lines.Add(new LineBuilder(ansi).Add(name, "1").Add(new string(' ', Math.Max(0, width - name.Length - domain.Length))).Add(domain).Build());
            }
            if (!string.IsNullOrEmpty(_tenant.Detail)) panel.Lines.Add(Truncate(new LineBuilder(ansi).Add(_tenant.Detail, "2").Build(), width, ansi));

            // The counts: each value over its label, right-aligned in columns of the same width. All in one row
            // when the panel is wide enough, else in rows of the same length.
            int count = Math.Min(_tenant.Labels.Length, _tenant.Values.Length);
            if (count > 0)
            {
                int perRow = Math.Max(1, Math.Min(count, width / 9));
                int rows = (count + perRow - 1) / perRow;
                perRow = (count + rows - 1) / rows;
                int cell = width / perRow;
                int first = 0;
                while (first < count)
                {
                    // Columns that do not divide the width leave their remainder on the left.
                    string lead = new string(' ', width - cell * perRow);
                    var values = new LineBuilder(ansi).Add(lead);
                    var labels = new LineBuilder(ansi).Add(lead);
                    int end = Math.Min(count, first + perRow);
                    for (int i = first; i < end; i++)
                    {
                        values.Add(Fit(_tenant.Values[i] ?? string.Empty, cell - 1).PadLeft(cell), "1");
                        labels.Add(Fit(_tenant.Labels[i] ?? string.Empty, cell - 1).PadLeft(cell), "2");
                    }
                    panel.Lines.Add(values.Build());
                    panel.Lines.Add(labels.Build());
                    first = end;
                }
            }
            return panel.Lines.Count > 0 ? panel : null;
        }

        private PanelContent BuildBlogPanel(int width, bool ansi)
        {
            if (string.IsNullOrEmpty(_blogPost.Title)) return null;
            var panel = new PanelContent { Title = "From the blog", Badge = string.IsNullOrEmpty(_blogPost.Published) ? null : _blogPost.Published };
            var wrapped = Wrap(_blogPost.Title, width);
            // Two lines at most: what is left over joins the second line, which is then cut.
            if (wrapped.Count > 2)
            {
                string rest = string.Join(" ", wrapped.GetRange(1, wrapped.Count - 1));
                wrapped.RemoveRange(1, wrapped.Count - 1);
                wrapped.Add(rest);
            }
            foreach (var text in wrapped)
            {
                var line = new Line { Text = ansi ? Hyperlink(text, _blogPost.Link) : text, Plain = text };
                panel.Lines.Add(Truncate(line, width, ansi));
            }
            return panel;
        }

        private PanelContent BuildFailedPanel(int width, bool ansi)
        {
            if (!_running && _sequence.Count == 0) return null;
            int max = 1;
            foreach (var s in SeverityOrder)
            {
                int c;
                _failedBySeverity.TryGetValue(s, out c);
                max = Math.Max(max, c);
            }
            var panel = new PanelContent { Title = "Failed so far", Badge = N(_failed), Colour = _failed > 0 ? "31" : null };
            int barWidth = Math.Max(4, width - 14);
            for (int i = 0; i < SeverityOrder.Length; i++)
            {
                int count;
                _failedBySeverity.TryGetValue(SeverityOrder[i], out count);
                var b = new LineBuilder(ansi).Add(SeverityOrder[i].PadRight(9), count > 0 ? null : "2");
                string bar = Bar((double)count / max * barWidth);
                b.Add(bar, SeverityColor[i]).Add(new string(' ', barWidth - bar.Length + 1)).Add(N(count).PadLeft(4), count > 0 ? SeverityColor[i] : "2");
                panel.Lines.Add(b.Build());
            }
            return panel;
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

        private PanelContent BuildPacePanel(int width, bool ansi)
        {
            if (_finishSeconds.Count == 0) return null;
            double elapsed = Math.Max(0.001, _running ? _runClock.Elapsed.TotalSeconds : _finishSeconds[_finishSeconds.Count - 1]);
            var panel = new PanelContent { Title = "Pace", Badge = (_finishSeconds.Count / elapsed).ToString("0.0", CultureInfo.InvariantCulture) + " tests/s" };

            // Tests finished in each slice of the run so far.
            int buckets = Math.Max(8, width);
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
            panel.Lines.Add(new LineBuilder(ansi).Add(spark.ToString(), "36").Build());

            if (_slowest.Count > 0)
            {
                panel.Lines.Add(new LineBuilder(ansi).Add("Slowest so far", "2").Build());
                foreach (var s in _slowest)
                {
                    if (panel.Lines.Count >= 2 + _slowestShown) break;
                    string time = Short(s.Duration).PadLeft(7);
                    var left = Truncate(new LineBuilder(ansi).Add((s.Id ?? string.Empty).PadRight(16) + " ").Add(s.Title, "2").Build(), width - time.Length, ansi);
                    string gap = new string(' ', Math.Max(0, width - time.Length - left.Plain.Length));
                    panel.Lines.Add(new Line { Text = left.Text + gap + time, Plain = left.Plain + gap + time });
                }
            }
            return panel;
        }

        private PanelContent BuildDriftPanel(int width, bool ansi)
        {
            if (_baseline == null) return null;
            var panel = new PanelContent { Title = "Drift since last run", Badge = _baselineLabel };
            if (_baselineWhen.HasValue) panel.Badge = FormatAge(DateTime.Now - _baselineWhen.Value);
            if (_newlyFailing.Count > 0) panel.Colour = Amber;
            else if (_fixedCount > 0) panel.Colour = "32";

            // What the last run found, and when.
            int passed = 0;
            int failed = 0;
            int investigate = 0;
            foreach (var result in _baseline.Values)
            {
                if (result == "Passed") passed++;
                else if (result == "Failed") failed++;
                else if (result == "Investigate") investigate++;
            }
            var last = new LineBuilder(ansi);
            if (_baselineWhen.HasValue) last.Add(_baselineWhen.Value.ToString("MMM d, HH:mm", CultureInfo.InvariantCulture) + "  ", "2");
            last.Add(Ok + " " + N(passed), "32").Add("  ").Add(Bad + " " + N(failed), failed > 0 ? "31" : "2").Add("  ").Add("? " + N(investigate), investigate > 0 ? "35" : "2");
            panel.Lines.Add(Truncate(last.Build(), width, ansi));
            if (_newlyFailing.Count == 0 && _fixedCount == 0 && _newTests == 0)
            {
                panel.Lines.Add(new LineBuilder(ansi).Add(_sequence.Count == 0 ? "Waiting for results" + Ellipsis() : "No changes so far", "2").Build());
                return panel;
            }
            if (_newlyFailing.Count > 0)
            {
                panel.Lines.Add(new LineBuilder(ansi).Add((Unicode ? "▲ " : "^ ") + N(_newlyFailing.Count) + " newly failing", "31").Build());
                panel.Lines.Add(Truncate(new LineBuilder(ansi).Add("  " + string.Join(Unicode ? " · " : ", ", _newlyFailing), "2").Build(), width, ansi));
            }
            if (_fixedCount > 0) panel.Lines.Add(new LineBuilder(ansi).Add((Unicode ? "▼ " : "v ") + N(_fixedCount) + " fixed", "32").Build());
            if (_newTests > 0) panel.Lines.Add(new LineBuilder(ansi).Add("+ " + N(_newTests) + " new test" + (_newTests == 1 ? string.Empty : "s"), "36").Build());
            return panel;
        }

        /// <summary>How long ago, in words: "just now", "10 min ago", "3 hours ago", "4 days ago", "2 months ago", "1 year ago".</summary>
        public static string FormatAge(TimeSpan age)
        {
            if (age.TotalMinutes < 1) return "just now";
            if (age.TotalHours < 1) return N((int)age.TotalMinutes) + " min ago";
            if (age.TotalDays < 1) return Count((int)age.TotalHours, "hour") + " ago";
            if (age.TotalDays < 30) return Count((int)age.TotalDays, "day") + " ago";
            if (age.TotalDays < 365) return Count((int)(age.TotalDays / 30), "month") + " ago";
            return Count((int)(age.TotalDays / 365), "year") + " ago";
        }

        private static string Count(int n, string unit)
        {
            return N(n) + " " + unit + (n == 1 ? string.Empty : "s");
        }

        private PanelContent BuildTipsPanel(int width, bool ansi)
        {
            if (_tips.Length == 0) return null;
            int index = (int)(_clock.Elapsed.TotalSeconds / 12) % _tips.Length;
            var panel = new PanelContent { Title = "Tip", Colour = "36" };
            foreach (var wrapped in Wrap(_tips[index], width)) panel.Lines.Add(new LineBuilder(ansi).Add(wrapped, "2").Build());
            string link = index < _tipLinks.Length ? _tipLinks[index] : null;
            if (!string.IsNullOrEmpty(link))
            {
                // The address without its scheme, so that it can be read (and typed) where it cannot be clicked.
                int scheme = link.IndexOf("://", StringComparison.Ordinal);
                string shown = scheme < 0 ? link : link.Substring(scheme + 3);
                var line = new Line { Text = ansi ? Esc + "36m" + Hyperlink(shown, link) + Esc + "0m" : shown, Plain = shown };
                panel.Lines.Add(Truncate(line, width, ansi));
            }
            return panel;
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
            // One square per test for as long as the rows that are free allow it.
            int columns = Math.Max(10, width - 2);
            int rows = Math.Min(16, maxRows);
            int perSquare = Math.Max(1, (int)Math.Ceiling((double)_total / (columns * rows)));
            int squares = (int)Math.Ceiling((double)_total / perSquare);
            bool caption = perSquare > 1 && maxRows > (int)Math.Ceiling((double)squares / columns);
            string mark = Unicode ? "■" : "#";
            // The tests that are running take the next places after the finished ones; their squares pulse.
            int done = _sequence.Count;
            int active = done + (_running ? _workers.Count : 0);
            string[] pulse = Unicode ? new[] { "·", "▪", "■", "▪" } : new[] { ".", "o", "O", "o" };

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
                if (last > done && first < active)
                {
                    row.Add(pulse[(_tick / 2) % pulse.Length], "1;97");
                }
                else if (first < done)
                {
                    row.Add(mark, SquareColour(first, Math.Min(last, done)));
                }
                else
                {
                    row.Add(ansi ? mark : (Unicode ? "□" : "."), "38;5;238");
                }
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
