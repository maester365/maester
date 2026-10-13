using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;

namespace Maester.Engine
{
    /// <summary>
    /// What the dashboard needs to know of a test for its insight panels: the attributes of [MaesterTest] that
    /// the panels count by. Given to the renderer once, before the tests start (SetTestInfo).
    /// </summary>
    public sealed class MtConsoleTestInfo
    {
        /// <summary>The ID the test reports with (the instance ID for a test of a family).</summary>
        public string Id { get; set; }

        /// <summary>Key of the area in the taxonomy registry.</summary>
        public string Area { get; set; }

        public string Severity { get; set; }
        public string UserImpact { get; set; }
        public string ImplementationCost { get; set; }

        /// <summary>MITRE ATT&amp;CK technique IDs.</summary>
        public string[] Mitre { get; set; }

        /// <summary>Control references, such as nist-800-53-r5:AC-2.</summary>
        public string[] Controls { get; set; }
    }

    /// <summary>
    /// The insight panels of the dashboard: what the results so far say about the tenant, counted by the
    /// attributes of the tests. Six are in the main column, under the list of tests, in rows of three:
    /// Weakest areas, ATT&amp;CK tactics and Failed tests, and on a console with the rows for it NIST 800-53
    /// families, Pass rate so far and Every test. Fix first is in the right column.
    ///
    /// A run of fewer than 25 tests has none of them, and nothing is counted for it. For the others each
    /// result adds to a few counters, and the panels are built from the counters: they are kept until the
    /// next test finishes, so a frame that only moves the clocks does not build them again.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const int InsightLeastTests = 25;
        private const int InsightRows = 7;
        private const int RecentLeast = 3;
        private const int AreaLeastTests = 5;
        private const int FamilyLeastTests = 3;
        private const int FixFirstMost = 6;
        private const int SlowestLeast = 2;
        // With rows to spare in the right column the Slowest panel lists up to this many.
        private const int SlowestMost = 5;
        private const string AreasPanel = "WeakestAreas";
        private const string TacticsPanel = "AttackTactics";
        private const string MatrixPanel = "FailedTests";
        private const string FamiliesPanel = "NistFamilies";
        private const string PassRatePanel = "PassRate";
        private const string EveryTestPanel = "EveryTest";
        private const string FixFirstPanel = "FixFirst";
        private const string NistPrefix = "nist-800-53-r5:";
        private const double ScatterFloor = 0.05;

        // The rows of insight panels, and for each place in a row the least width of its panel, its share of
        // the columns that are left over and the most it takes. The bars need the most room; the panel in
        // the middle grows only when the other two have all they take.
        private static readonly string[][] InsightLayout =
        {
            new[] { AreasPanel, TacticsPanel, MatrixPanel },
            new[] { FamiliesPanel, PassRatePanel, EveryTestPanel }
        };
        private static readonly int[] InsightLeastWidth = { 36, 28, 27 };
        private static readonly int[] InsightShare = { 2, 0, 1 };
        private static readonly int[] InsightMostWidth = { 60, 44, 44 };
        private static readonly string[] LevelOrder = { "Low", "Medium", "High" };
        private static readonly string[] LevelLabel = { "Low", "Med", "High" };
        private const string SeverityLetters = "CHML";

        // The tactics of ATT&CK in a word of at most seven letters, for under a bar.
        private static readonly Dictionary<string, string> TacticShort = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "Reconnaissance", "Recon" }, { "Resource Development", "ResDev" }, { "Initial Access", "Initial" },
            { "Execution", "Execute" }, { "Persistence", "Persist" }, { "Privilege Escalation", "PrivEsc" },
            { "Defense Evasion", "Evasion" }, { "Defense Impairment", "Impair" }, { "Credential Access", "Creds" },
            { "Discovery", "Discov." }, { "Lateral Movement", "Lateral" }, { "Collection", "Collect" },
            { "Command and Control", "C2" }, { "Exfiltration", "Exfil" }
        };

        /// <summary>The tests of an area or of a control family: how many passed or failed, and how many failed.</summary>
        private sealed class RateGroup
        {
            public string Code;
            public string Name;
            public int Done;
            public int Failed;
        }

        private sealed class Tactic
        {
            public string Name;
            public int Failed;
        }

        /// <summary>The attributes of one test, resolved once to the counters its result adds to.</summary>
        private sealed class TestFacts
        {
            public RateGroup Area;
            public RateGroup[] Families;
            public Tactic[] Tactics;
            public int Severity = 3;
            public int Impact = -1;
            public int Cost = -1;
        }

        private sealed class QuickWin
        {
            public string Id;
            public string Title;
            public bool Critical;
        }

        private Dictionary<string, TestFacts> _facts;
        private readonly List<RateGroup> _areas = new List<RateGroup>();
        private readonly List<RateGroup> _families = new List<RateGroup>();
        private readonly List<Tactic> _tactics = new List<Tactic>();
        private readonly int[] _matrix = new int[3 * 3 * 4];
        private int _matrixCount;
        private int _tacticFailures;
        private readonly List<float> _rate = new List<float>();
        private int _ratePassed;
        private double _rateLow = 1;
        private double _rateLowEarly = 1;
        private readonly List<bool> _ranFailed = new List<bool>();
        private readonly List<QuickWin> _quick = new List<QuickWin>();
        private bool _insights;
        private int _insightVersion;
        private List<Line> _insightCache;
        private int _insightCacheVersion = -1;
        private int _insightCacheWidth;
        private int _insightCacheRows;
        private bool _insightCacheAnsi;
        private bool _insightCacheUnicode;
        private int _slowRows = SlowestLeast;
        private int _fixRows = FixFirstMost;

        /// <summary>
        /// The attributes of the tests of the run, for the insight panels, and the names the panels show: of
        /// the areas (key to name), of the tactic of each ATT&amp;CK technique (technique ID to tactic name) and
        /// of the NIST 800-53 control families (family code to name). Call it before Start. A test that is not
        /// listed (a Pester test has no attributes) adds to the pass rate and the timings only. Null for the
        /// tests turns the panels off.
        /// </summary>
        public void SetTestInfo(MtConsoleTestInfo[] tests, IDictionary areaNames, IDictionary techniqueTactics, IDictionary familyNames)
        {
            lock (_gate)
            {
                try
                {
                    LoadTestInfo(tests, areaNames, techniqueTactics, familyNames);
                }
                catch (Exception)
                {
                    // Attributes that cannot be read only mean there are no insight panels.
                    _facts = null;
                }
                ResetInsights();
                // A run that already has results keeps what it shows: the counters would miss those results.
                if (_running) _insights = _facts != null && _total >= InsightLeastTests && _sequence.Count == 0;
                Redraw();
            }
        }

        private void LoadTestInfo(MtConsoleTestInfo[] tests, IDictionary areaNames, IDictionary techniqueTactics, IDictionary familyNames)
        {
            _facts = null;
            _areas.Clear();
            _families.Clear();
            _tactics.Clear();
            if (tests == null || tests.Length == 0) return;
            var facts = new Dictionary<string, TestFacts>(tests.Length, StringComparer.OrdinalIgnoreCase);
            var areas = new Dictionary<string, RateGroup>(StringComparer.OrdinalIgnoreCase);
            var families = new Dictionary<string, RateGroup>(StringComparer.OrdinalIgnoreCase);
            var tactics = new Dictionary<string, Tactic>(StringComparer.OrdinalIgnoreCase);
            var ofTest = new List<Tactic>();
            var familiesOfTest = new List<RateGroup>();
            foreach (var t in tests)
            {
                // The key is the ID as ItemStarting and ItemFinished store it.
                string id = t == null ? null : PlainText(t.Id);
                if (string.IsNullOrEmpty(id)) continue;
                var f = new TestFacts { Impact = Array.IndexOf(LevelOrder, Normalise(t.UserImpact, LevelOrder)), Cost = Array.IndexOf(LevelOrder, Normalise(t.ImplementationCost, LevelOrder)) };
                int severity = Array.IndexOf(SeverityOrder, Normalise(t.Severity));
                if (severity >= 0) f.Severity = severity;
                if (!string.IsNullOrEmpty(t.Area))
                {
                    if (!areas.TryGetValue(t.Area, out f.Area))
                    {
                        f.Area = new RateGroup { Name = PlainText(Named(areaNames, t.Area) ?? t.Area) };
                        areas[t.Area] = f.Area;
                        _areas.Add(f.Area);
                    }
                }
                // A test counts once for a tactic, however many of its techniques belong to it.
                ofTest.Clear();
                foreach (string technique in t.Mitre ?? new string[0])
                {
                    string name = TacticOf(techniqueTactics, technique);
                    if (string.IsNullOrEmpty(name)) continue;
                    Tactic tactic;
                    if (!tactics.TryGetValue(name, out tactic))
                    {
                        tactic = new Tactic { Name = PlainText(name) };
                        tactics[name] = tactic;
                        _tactics.Add(tactic);
                    }
                    if (!ofTest.Contains(tactic)) ofTest.Add(tactic);
                }
                if (ofTest.Count > 0) f.Tactics = ofTest.ToArray();
                // And once for a control family.
                familiesOfTest.Clear();
                foreach (string control in t.Controls ?? new string[0])
                {
                    string code = FamilyOf(control);
                    if (code == null) continue;
                    RateGroup family;
                    if (!families.TryGetValue(code, out family))
                    {
                        family = new RateGroup { Code = code, Name = PlainText(Named(familyNames, code) ?? string.Empty) };
                        families[code] = family;
                        _families.Add(family);
                    }
                    if (!familiesOfTest.Contains(family)) familiesOfTest.Add(family);
                }
                if (familiesOfTest.Count > 0) f.Families = familiesOfTest.ToArray();
                facts[id] = f;
            }
            _facts = facts;
        }

        private static string Named(IDictionary names, string key)
        {
            if (names == null || string.IsNullOrEmpty(key) || !names.Contains(key)) return null;
            object value = names[key];
            return value == null ? null : value.ToString();
        }

        /// <summary>The tactic of a technique; a sub-technique that is not listed has the tactic of its technique.</summary>
        private static string TacticOf(IDictionary techniqueTactics, string technique)
        {
            if (string.IsNullOrEmpty(technique)) return null;
            technique = technique.Trim();
            string name = Named(techniqueTactics, technique);
            int dot = technique.IndexOf('.');
            return name == null && dot > 0 ? Named(techniqueTactics, technique.Substring(0, dot)) : name;
        }

        /// <summary>The family of a NIST 800-53 control reference: the letters before the dash (nist-800-53-r5:AC-2 is AC).</summary>
        private static string FamilyOf(string control)
        {
            if (string.IsNullOrEmpty(control) || !control.StartsWith(NistPrefix, StringComparison.OrdinalIgnoreCase)) return null;
            int dash = control.IndexOf('-', NistPrefix.Length);
            if (dash <= NistPrefix.Length || dash - NistPrefix.Length > 4) return null;
            string code = control.Substring(NistPrefix.Length, dash - NistPrefix.Length).ToUpperInvariant();
            foreach (char c in code)
            {
                if (c < 'A' || c > 'Z') return null;
            }
            return code;
        }

        private static string Normalise(string value, string[] known)
        {
            if (string.IsNullOrEmpty(value)) return string.Empty;
            foreach (var k in known)
            {
                if (string.Equals(k, value, StringComparison.OrdinalIgnoreCase)) return k;
            }
            return value;
        }

        // ------------------------------------------------------------------ counting (callers hold _gate)

        private void ResetInsights()
        {
            foreach (var g in _areas) g.Done = g.Failed = 0;
            foreach (var g in _families) g.Done = g.Failed = 0;
            foreach (var t in _tactics) t.Failed = 0;
            Array.Clear(_matrix, 0, _matrix.Length);
            _matrixCount = 0;
            _tacticFailures = 0;
            _rate.Clear();
            _ratePassed = 0;
            _rateLow = _rateLowEarly = 1;
            _ranFailed.Clear();
            _quick.Clear();
            _insights = false;
            _insightVersion++;
        }

        /// <summary>Adds a result to the counters of the insight panels: a few additions, and nothing is looked for.</summary>
        private void RecordInsight(string id, string title, string result)
        {
            _insightVersion++;
            bool failed = result == "Failed";
            if (!failed && result != "Passed") return;
            if (!failed) _ratePassed++;
            double rate = (double)_ratePassed / (_rate.Count + 1);
            _rate.Add((float)rate);
            // The scale of the Pass rate panel starts at the lowest rate after the first twenty tests: the
            // first few results swing it too far to say anything.
            if (_rate.Count > 20) _rateLow = Math.Min(_rateLow, rate);
            else _rateLowEarly = Math.Min(_rateLowEarly, rate);

            TestFacts f;
            if (string.IsNullOrEmpty(id) || !_facts.TryGetValue(id, out f)) return;
            if (f.Area != null)
            {
                f.Area.Done++;
                if (failed) f.Area.Failed++;
            }
            if (f.Families != null)
            {
                foreach (var family in f.Families)
                {
                    family.Done++;
                    if (failed) family.Failed++;
                }
            }
            if (!failed) return;
            if (f.Tactics != null)
            {
                foreach (var tactic in f.Tactics) tactic.Failed++;
                _tacticFailures++;
            }
            if (f.Impact < 0 || f.Cost < 0) return;
            _matrix[(f.Cost * 3 + f.Impact) * 4 + f.Severity]++;
            _matrixCount++;
            if (f.Severity > 1 || f.Impact != 0 || f.Cost != 0) return;
            // A quick win: Critical before High, then by ID. The list is a handful of tests.
            var win = new QuickWin { Id = id, Title = title, Critical = f.Severity == 0 };
            int at = _quick.Count;
            while (at > 0 && QuickBefore(win, _quick[at - 1])) at--;
            _quick.Insert(at, win);
        }

        private static bool QuickBefore(QuickWin a, QuickWin b)
        {
            if (a.Critical != b.Critical) return a.Critical;
            return string.Compare(a.Id, b.Id, StringComparison.OrdinalIgnoreCase) < 0;
        }

        // ------------------------------------------------------------------ the panels of the main column

        private static bool IsInsightPanel(string name)
        {
            foreach (var row in InsightLayout)
            {
                foreach (var panel in row)
                {
                    if (string.Equals(panel, name, StringComparison.OrdinalIgnoreCase)) return true;
                }
            }
            return false;
        }

        /// <summary>
        /// The insight panels for the main column: as many of the two rows of panels as fit in
        /// <paramref name="room"/> rows, each at its full height. The second row is the first to go. Nothing
        /// when the run has no insight panels or there is no room for one row.
        /// </summary>
        private List<Line> BuildInsights(int max, int room, bool ansi)
        {
            int most = _insights ? Math.Min(InsightLayout.Length, room / (InsightRows + 2)) : 0;
            if (most < 1) return new List<Line>();
            bool kept = _insightCache != null && _insightCacheVersion == _insightVersion && _insightCacheWidth == max &&
                _insightCacheRows == most && _insightCacheAnsi == ansi && _insightCacheUnicode == Unicode;
            if (kept) return _insightCache;
            var lines = new List<Line>();
            try
            {
                int rows = 0;
                foreach (var names in InsightLayout)
                {
                    if (rows >= most) break;
                    var row = BuildInsightRow(names, max, ansi);
                    if (row.Count == 0) continue;
                    lines.AddRange(row);
                    rows++;
                }
            }
            catch (Exception)
            {
                // A panel that cannot be drawn must not cost the frame: the dashboard is drawn without the panels.
                lines.Clear();
            }
            _insightCache = lines;
            _insightCacheVersion = _insightVersion;
            _insightCacheWidth = max;
            _insightCacheRows = most;
            _insightCacheAnsi = ansi;
            _insightCacheUnicode = Unicode;
            return lines;
        }

        /// <summary>
        /// One row of panels, side by side: those that are turned on and have something to show, as many as
        /// the width has room for, each as wide as its place in the row asks.
        /// </summary>
        private List<Line> BuildInsightRow(string[] names, int max, bool ansi)
        {
            var lines = new List<Line>();
            int room = max - 1;
            var places = new List<int>();
            int least = 0;
            for (int i = 0; i < names.Length; i++)
            {
                if (!PanelShown(names[i]) || !InsightHasData(names[i])) continue;
                int need = InsightLeastWidth[i] + (places.Count > 0 ? 1 : 0);
                if (least + need > room) break;
                places.Add(i);
                least += need;
            }
            if (places.Count == 0) return lines;
            int shares = 0;
            foreach (int i in places) shares += InsightShare[i];
            int extra = room - least;
            var widths = new int[places.Count];
            int given = 0;
            for (int p = 0; p < places.Count; p++)
            {
                int i = places[p];
                widths[p] = Math.Min(InsightMostWidth[i], InsightLeastWidth[i] + (shares > 0 ? extra * InsightShare[i] / shares : 0));
                given += widths[p] - InsightLeastWidth[i];
            }
            // The columns that the division left over, one at a time: to the panels that have a share first,
            // and to the others when those have all they take.
            for (int phase = 0; phase < 2; phase++)
            {
                bool any = true;
                while (given < extra && any)
                {
                    any = false;
                    for (int p = 0; p < places.Count && given < extra; p++)
                    {
                        if ((InsightShare[places[p]] > 0) != (phase == 0) || widths[p] >= InsightMostWidth[places[p]]) continue;
                        widths[p]++;
                        given++;
                        any = true;
                    }
                }
            }
            var boxes = new List<List<Line>>();
            for (int p = 0; p < places.Count; p++)
            {
                int i = places[p];
                int width = widths[p];
                var panel = BuildInsightPanel(names[i], width - 4, ansi);
                while (panel.Lines.Count < InsightRows) panel.Lines.Add(new Line { Text = string.Empty, Plain = string.Empty });
                if (panel.Lines.Count > InsightRows) panel.Lines.RemoveRange(InsightRows, panel.Lines.Count - InsightRows);
                boxes.Add(Box(panel, width, ansi));
            }
            for (int r = 0; r < InsightRows + 2; r++)
            {
                var text = new StringBuilder();
                var plain = new StringBuilder();
                foreach (var box in boxes)
                {
                    text.Append(' ').Append(box[r].Text);
                    plain.Append(' ').Append(box[r].Plain);
                }
                lines.Add(new Line { Text = text.ToString(), Plain = plain.ToString() });
            }
            return lines;
        }

        private bool InsightHasData(string name)
        {
            switch (name)
            {
                case AreasPanel:
                    return AnyRate(_areas, AreaLeastTests);
                case FamiliesPanel:
                    return AnyRate(_families, FamilyLeastTests);
                case TacticsPanel:
                    return _tacticFailures > 0;
                case MatrixPanel:
                    return _matrixCount > 0;
                case PassRatePanel:
                    return _rate.Count > 0;
                default:
                    return _durations.Count > 0;
            }
        }

        private static bool AnyRate(List<RateGroup> groups, int least)
        {
            foreach (var g in groups)
            {
                if (g.Done >= least && g.Failed > 0) return true;
            }
            return false;
        }

        private PanelContent BuildInsightPanel(string name, int width, bool ansi)
        {
            switch (name)
            {
                case AreasPanel:
                    return BuildRatePanel("Weakest areas", _areas, AreaLeastTests, width, ansi);
                case FamiliesPanel:
                    return BuildRatePanel("NIST 800-53 families", _families, FamilyLeastTests, width, ansi);
                case TacticsPanel:
                    return BuildTacticsPanel(width, ansi);
                case MatrixPanel:
                    return BuildMatrixPanel(width, ansi);
                case PassRatePanel:
                    return BuildPassRatePanel(width, ansi);
                default:
                    return BuildEveryTestPanel(width, ansi);
            }
        }

        /// <summary>Text in at most <paramref name="width"/> columns: a longer one ends with an ellipsis.</summary>
        private string Cut(string s, int width)
        {
            s = s ?? string.Empty;
            if (s.Length <= width) return s;
            return width < 1 ? string.Empty : s.Substring(0, width - 1).TrimEnd() + (Unicode ? "…" : ".");
        }

        private static string Centre(string s, int width)
        {
            if (s.Length >= width) return s.Substring(0, width);
            return s.PadLeft(s.Length + (width - s.Length) / 2).PadRight(width);
        }

        /// <summary>The colour of a pass rate: red under 70%, yellow under 85%, green from there.</summary>
        private static string RateColour(double rate)
        {
            return rate < 0.7 ? "31" : (rate < 0.85 ? "33" : "32");
        }

        /// <summary>
        /// Weakest areas, and NIST 800-53 families: the groups with enough tests and a failure among them, the
        /// lowest pass rate first. A row is the name, a bar of the share that passed, the percentage and the
        /// number of failed tests.
        /// </summary>
        private PanelContent BuildRatePanel(string title, List<RateGroup> groups, int least, int width, bool ansi)
        {
            var shown = new List<RateGroup>();
            foreach (var g in groups)
            {
                if (g.Done >= least && g.Failed > 0) shown.Add(g);
            }
            shown.Sort((a, b) =>
            {
                // The larger share of failures first, without dividing.
                long x = (long)a.Failed * b.Done;
                long y = (long)b.Failed * a.Done;
                if (x != y) return y.CompareTo(x);
                if (a.Failed != b.Failed) return b.Failed.CompareTo(a.Failed);
                return string.CompareOrdinal(a.Code ?? a.Name, b.Code ?? b.Name);
            });
            if (shown.Count > InsightRows) shown.RemoveRange(InsightRows, shown.Count - InsightRows);
            var panel = new PanelContent { Title = title, Badge = Unicode ? "pass · fail" : "pass, fail" };

            // The numbers take ten columns and the bar a quarter of the rest at least; the names get what is
            // left, as far as they need it.
            const int numbers = 10;
            int codeWidth = 0;
            int longest = 0;
            foreach (var g in shown)
            {
                if (g.Code != null) codeWidth = Math.Max(codeWidth, g.Code.Length + 1);
                longest = Math.Max(longest, g.Name.Length);
            }
            int barLeast = Math.Max(6, (width - codeWidth - numbers) / 4);
            int nameWidth = Math.Max(0, Math.Min(longest, width - codeWidth - numbers - barLeast - 1));
            int barWidth = Math.Max(1, width - codeWidth - numbers - (nameWidth > 0 ? nameWidth + 1 : 0));
            foreach (var g in shown)
            {
                double rate = (double)(g.Done - g.Failed) / g.Done;
                string colour = RateColour(rate);
                var b = new LineBuilder(ansi);
                if (g.Code != null) b.Add(g.Code.PadRight(codeWidth), "1");
                if (nameWidth > 0) b.Add(Cut(g.Name, nameWidth).PadRight(nameWidth + 1));
                string bar = Bar(rate * barWidth);
                if (bar.Length > barWidth) bar = bar.Substring(0, barWidth);
                b.Add(bar, colour).Add(new string(Unicode ? '░' : '-', barWidth - bar.Length), "38;5;238");
                b.Add((N((int)Math.Round(rate * 100)) + "%").PadLeft(5), colour);
                b.Add(" " + Bad + N(g.Failed).PadLeft(3), "31");
                panel.Lines.Add(b.Build());
            }
            return panel;
        }

        /// <summary>
        /// ATT&amp;CK tactics: a bar for each tactic that failed tests guard against, the tactic with the most
        /// first. The count is above the bar and the name under it, in a word when it does not fit.
        /// </summary>
        private PanelContent BuildTacticsPanel(int width, bool ansi)
        {
            var shown = new List<Tactic>();
            foreach (var t in _tactics)
            {
                if (t.Failed > 0) shown.Add(t);
            }
            shown.Sort((a, b) => a.Failed != b.Failed ? b.Failed.CompareTo(a.Failed) : string.CompareOrdinal(a.Name, b.Name));
            // A bar and its gap take eight columns at least, so that a word fits under it.
            int count = Math.Max(1, Math.Min(shown.Count, (width + 1) / 8));
            int cell = Math.Min(12, (width + 1) / count) - 1;
            int rows = InsightRows - 2;
            int most = shown[0].Failed;
            var panel = new PanelContent { Title = "ATT&CK tactics", Badge = "failed tests" };

            var counts = new LineBuilder(ansi);
            var labels = new LineBuilder(ansi);
            var bars = new LineBuilder[rows];
            for (int r = 0; r < rows; r++) bars[r] = new LineBuilder(ansi);
            for (int i = 0; i < count; i++)
            {
                var t = shown[i];
                string colour = (double)t.Failed / most > 0.6 ? "31" : "33";
                string gap = i < count - 1 ? " " : string.Empty;
                counts.Add(Centre(N(t.Failed), cell) + gap, colour);
                labels.Add(Centre(TacticLabel(t.Name, cell), cell) + gap, "2");
                // A tactic with a failure always shows, however far it is behind the first.
                int level = Math.Max(1, (int)Math.Round((double)t.Failed / most * rows * 8));
                for (int r = 0; r < rows; r++)
                {
                    int part = Math.Max(0, Math.Min(8, level - (rows - 1 - r) * 8));
                    char c;
                    if (part == 0) c = ' ';
                    else if (Unicode) c = Spark[part - 1];
                    else c = part >= 7 ? '#' : (part >= 4 ? ':' : '.');
                    bars[r].Add(Centre(new string(c, Math.Max(1, cell - 2)), cell) + gap, colour);
                }
            }
            panel.Lines.Add(counts.Build());
            foreach (var bar in bars) panel.Lines.Add(bar.Build());
            panel.Lines.Add(labels.Build());
            return panel;
        }

        /// <summary>The name of a tactic for under its bar: whole when it fits, else its short word, else its initials.</summary>
        private static string TacticLabel(string name, int width)
        {
            if (name.Length <= width) return name;
            string word;
            if (TacticShort.TryGetValue(name, out word) && word.Length <= width) return word;
            if (name.IndexOf(' ') < 0) return name.Substring(0, Math.Max(0, width));
            var initials = new StringBuilder();
            foreach (var part in name.Split(' '))
            {
                if (part.Length > 0 && char.IsUpper(part[0])) initials.Append(part[0]);
            }
            return initials.Length <= width ? initials.ToString() : initials.ToString(0, Math.Max(0, width));
        }

        /// <summary>
        /// Failed tests: one dot for each, placed by what the fix asks for (the impact on users across, the
        /// effort down) and coloured by severity, the most severe first. The cheap fixes are at the top left.
        /// A cell with more tests than it has room for ends with their number. Without colour a dot is the
        /// first letter of its severity.
        /// </summary>
        private PanelContent BuildMatrixPanel(int width, bool ansi)
        {
            const int labelWidth = 7;
            int cellWidth = Math.Max(4, (width - labelWidth) / 3);
            var panel = new PanelContent { Title = "Failed tests" };
            panel.Lines.Add(new LineBuilder(ansi).Add(new string(' ', labelWidth) + (width - labelWidth >= 22 ? "user impact of the fix" : "user impact"), "2").Build());
            panel.Lines.Add(new LineBuilder(ansi).Add("effort".PadRight(labelWidth) + LevelLabel[0].PadRight(cellWidth) + LevelLabel[1].PadRight(cellWidth) + LevelLabel[2], "2").Build());
            // The rows that are left are shared by the three levels of effort, the low ones first.
            int dotRows = InsightRows - 2;
            char dot = Unicode ? '●' : '*';
            for (int cost = 0; cost < 3; cost++)
            {
                int subRows = dotRows / 3 + (cost < dotRows % 3 ? 1 : 0);
                int capacity = subRows * (cellWidth - 1);
                for (int sub = 0; sub < subRows; sub++)
                {
                    var b = new LineBuilder(ansi).Add((sub == 0 ? LevelLabel[cost] : string.Empty).PadRight(labelWidth), "2");
                    for (int impact = 0; impact < 3; impact++)
                    {
                        int first = (cost * 3 + impact) * 4;
                        int total = _matrix[first] + _matrix[first + 1] + _matrix[first + 2] + _matrix[first + 3];
                        // The dots that are drawn, and the number of the tests that are not.
                        int drawn = total;
                        string more = string.Empty;
                        for (int length = 2; total > capacity && more.Length == 0; length++)
                        {
                            drawn = Math.Max(0, capacity - length);
                            string text = "+" + N(total - drawn);
                            if (text.Length <= length || drawn == 0) more = text;
                        }
                        int from = sub * (cellWidth - 1);
                        int to = Math.Min(drawn, from + cellWidth - 1);
                        int used = 0;
                        int before = 0;
                        for (int severity = 0; severity < 4; severity++)
                        {
                            int lo = Math.Max(from, before);
                            int hi = Math.Min(to, before + _matrix[first + severity]);
                            before += _matrix[first + severity];
                            if (hi <= lo) continue;
                            b.Add(new string(ansi ? dot : SeverityLetters[severity], hi - lo), SeverityColor[severity]);
                            used += hi - lo;
                        }
                        if (sub == subRows - 1 && more.Length > 0)
                        {
                            b.Add(more, "2");
                            used += more.Length;
                        }
                        if (impact < 2) b.Add(new string(' ', Math.Max(0, cellWidth - used)));
                    }
                    panel.Lines.Add(b.Build());
                }
            }
            return panel;
        }

        /// <summary>
        /// Pass rate so far: the share of passed tests among the passed and failed ones, from the first test
        /// to now, as a line. The scale is from the lowest rate after the first twenty tests to 100%.
        /// </summary>
        private PanelContent BuildPassRatePanel(int width, bool ansi)
        {
            const int labelWidth = 5;
            int plotWidth = Math.Max(1, width - labelWidth);
            int rows = InsightRows - 1;
            int levels = rows * 2;
            int n = _rate.Count;
            double low = n > 20 ? _rateLow : _rateLowEarly;
            double span = Math.Max(0.05, 1 - low);
            var panel = new PanelContent { Title = "Pass rate so far", Badge = N((int)Math.Round(_rate[n - 1] * 100)) + "%" };
            var grid = new char[rows][];
            for (int r = 0; r < rows; r++) grid[r] = new string(' ', plotWidth).ToCharArray();
            for (int x = 0; x < plotWidth; x++)
            {
                // One point per column, the newest result in the last one. Two levels in a row.
                double value = _rate[plotWidth > 1 ? (int)((long)x * (n - 1) / (plotWidth - 1)) : n - 1];
                int level = (int)Math.Round(Math.Max(0, Math.Min(1, (value - (1 - span)) / span)) * (levels - 1));
                bool upper = (level & 1) != 0;
                grid[rows - 1 - level / 2][x] = Unicode ? (upper ? '▀' : '▄') : (upper ? '-' : '_');
            }
            for (int r = 0; r < rows; r++)
            {
                string label = r == 0 ? "100%" : (r == rows - 1 ? N((int)Math.Round((1 - span) * 100)) + "%" : string.Empty);
                panel.Lines.Add(new LineBuilder(ansi).Add(label.PadLeft(labelWidth - 1) + " ", "2").Add(new string(grid[r]), "32").Build());
            }
            panel.Lines.Add(AxisLine(labelWidth, plotWidth, ansi));
            return panel;
        }

        /// <summary>The line under a chart that runs from the first test to the newest.</summary>
        private Line AxisLine(int labelWidth, int plotWidth, bool ansi)
        {
            const string first = "first test";
            const string now = "now";
            string text = plotWidth >= first.Length + now.Length + 2
                ? first + new string(' ', plotWidth - first.Length - now.Length) + now
                : now.PadLeft(Math.Max(now.Length, plotWidth));
            return new LineBuilder(ansi).Add(new string(' ', labelWidth) + text, "2").Build();
        }

        /// <summary>
        /// Every test: a point for each test that ran, in the order they finished across and by how long it
        /// took up, on a logarithmic scale (as the Pace graph). Braille dots give four points in the height of
        /// a row and two in a column; a cell with a failed test in it is red. Without Unicode a cell is one
        /// character, heavier with more tests in it, and without colour as well an x marks a failed test.
        /// </summary>
        private PanelContent BuildEveryTestPanel(int width, bool ansi)
        {
            int n = _durations.Count;
            double longest = 0;
            for (int i = 0; i < n; i++) longest = Math.Max(longest, _durations[i]);
            string topLabel = Short(TimeSpan.FromSeconds(longest));
            int labelWidth = Math.Max(5, topLabel.Length) + 1;
            int plotWidth = Math.Max(1, width - labelWidth);
            int rows = InsightRows - 1;
            int across = Unicode ? plotWidth * 2 : plotWidth;
            int up = Unicode ? rows * 4 : rows;
            double top = Math.Log(1 + Math.Max(1.0, longest) / ScatterFloor);
            var cells = new int[rows * plotWidth];
            var red = new bool[rows * plotWidth];
            for (int i = 0; i < n; i++)
            {
                int x = (int)((long)i * across / n);
                int y = up - 1 - Math.Min(up - 1, (int)(Math.Log(1 + _durations[i] / ScatterFloor) / top * up));
                int at = Unicode ? y / 4 * plotWidth + x / 2 : y * plotWidth + x;
                // Unicode: the bit of the dot in its braille cell. Otherwise the number of tests in the cell.
                int dot = y & 3;
                if (Unicode) cells[at] |= (x & 1) == 0 ? (dot == 3 ? 0x40 : 1 << dot) : (dot == 3 ? 0x80 : 8 << dot);
                else cells[at]++;
                if (i < _ranFailed.Count && _ranFailed[i]) red[at] = true;
            }
            var panel = new PanelContent { Title = "Every test", Badge = "time taken" };
            var run = new StringBuilder();
            for (int r = 0; r < rows; r++)
            {
                string label = r == 0 ? topLabel : (r == rows - 1 ? Short(TimeSpan.Zero) : string.Empty);
                var b = new LineBuilder(ansi).Add(label.PadLeft(labelWidth - 1) + " ", "2");
                // Cells of one colour that follow each other are written together.
                bool runRed = false;
                run.Clear();
                for (int x = 0; x < plotWidth; x++)
                {
                    int cell = cells[r * plotWidth + x];
                    bool failed = red[r * plotWidth + x];
                    char c;
                    if (cell == 0) c = ' ';
                    else if (Unicode) c = (char)(0x2800 + cell);
                    else if (failed && !ansi) c = 'x';
                    else c = cell >= 4 ? '#' : (cell >= 2 ? ':' : '.');
                    if (cell != 0 && failed != runRed && run.Length > 0)
                    {
                        b.Add(run.ToString(), runRed ? "31" : "32");
                        run.Clear();
                    }
                    if (cell != 0) runRed = failed;
                    run.Append(c);
                }
                b.Add(run.ToString(), runRed ? "31" : "32");
                panel.Lines.Add(b.Build());
            }
            panel.Lines.Add(AxisLine(labelWidth, plotWidth, ansi));
            return panel;
        }

        // ------------------------------------------------------------------ the panel of the right column

        /// <summary>
        /// Fix first: the failed tests that are worth the most for the least, Critical or High with a fix that
        /// users do not notice and that costs little. Critical first, then by ID; six at most, and fewer in a
        /// column that is short of rows.
        /// </summary>
        private PanelContent BuildFixFirstPanel(int width, bool ansi)
        {
            if (!_insights || _quick.Count == 0 || _fixRows < 1) return null;
            var panel = new PanelContent { Title = "Fix first", Badge = N(_quick.Count) + (_quick.Count == 1 ? " quick win" : " quick wins") };
            string dot = Unicode ? " · " : ", ";
            panel.Lines.Add(Truncate(new LineBuilder(ansi).Add("High or Critical" + dot + "low user impact" + dot + "low cost", "2").Build(), width, ansi));
            int shown = Math.Min(_quick.Count, _fixRows);
            for (int i = 0; i < shown; i++)
            {
                var b = new LineBuilder(ansi).Add(Bad + " ", "31").Add(FitId(_quick[i].Id) + " ").Add(_quick[i].Title, "2");
                panel.Lines.Add(Truncate(b.Build(), width, ansi));
            }
            if (_quick.Count > shown) panel.Lines.Add(new LineBuilder(ansi).Add("  and " + N(_quick.Count - shown) + " more", "2").Build());
            return panel;
        }
    }
}
