using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Maester.Engine
{
    /// <summary>
    /// A contributor for the Featured contributor panel of the dashboard: the name, the GitHub handle, how many
    /// tests the person wrote and how many they improved, and the year of their first contribution.
    /// </summary>
    public sealed class MtContributor
    {
        public string Name { get; set; }
        public string GitHub { get; set; }
        public int Tests { get; set; }
        public int Improvements { get; set; }
        public int Since { get; set; }
    }

    /// <summary>
    /// Two panels of the right column: Totals, the results so far as a bar split by result, and Contributor,
    /// one of the people who built Maester, a different one every minute.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const int TotalsEmpty = 5;
        private const string ContributorSite = "https://maester.dev/contributors/";
        private const int ContributorSeconds = 60;

        // Passed, failed, error, investigate, skipped, and the bar before there are results.
        private static readonly string[] TotalsFg = { "32", "31", "33", "35", "38;5;244", "38;5;238" };
        private static readonly string[] TotalsBg = { "42", "41", "43", "45", "48;5;244", "48;5;238" };

        private MtContributor[] _contributors = new MtContributor[0];
        private int _contributorStart;

        /// <summary>
        /// The people of the Featured contributor panel. One is shown at a time, for a minute each,
        /// beginning with the one at <paramref name="start"/> (any number: it wraps around).
        /// </summary>
        public void SetContributors(MtContributor[] contributors, int start)
        {
            var kept = new List<MtContributor>();
            foreach (var c in contributors ?? new MtContributor[0])
            {
                if (c == null) continue;
                string handle = MtConsoleFeeds.Clean(c.GitHub);
                if (!IsHandle(handle)) continue;
                string name = MtConsoleFeeds.Clean(c.Name);
                kept.Add(new MtContributor { Name = name.Length > 0 ? name : handle, GitHub = handle, Tests = c.Tests, Improvements = c.Improvements, Since = c.Since });
            }
            lock (_gate)
            {
                _contributors = kept.ToArray();
                _contributorStart = kept.Count > 0 ? ((start % kept.Count) + kept.Count) % kept.Count : 0;
                Redraw();
            }
        }

        /// <summary>
        /// Reads the contributors from the JSON file that ships with the module (an array of objects with Name,
        /// GitHub, Tests, Improvements and Since) on a background thread. A file that cannot be read means no panel.
        /// </summary>
        public Task LoadContributorsAsync(string path, int start)
        {
            return Task.Run(() =>
            {
                try
                {
                    byte[] bytes = File.ReadAllBytes(path);
                    bool bom = bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
                    var json = new ReadOnlySpan<byte>(bytes, bom ? 3 : 0, bytes.Length - (bom ? 3 : 0));
                    SetContributors(JsonSerializer.Deserialize<MtContributor[]>(json), start);
                }
                catch (Exception)
                {
                    // A missing or damaged file only means there is no Featured contributor panel.
                }
            });
        }

        /// <summary>A GitHub handle: letters, digits and hyphens. Anything else does not go into an address.</summary>
        private static bool IsHandle(string handle)
        {
            if (string.IsNullOrEmpty(handle) || handle.Length > 39) return false;
            foreach (char c in handle)
            {
                bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-';
                if (!ok) return false;
            }
            return true;
        }

        private PanelContent BuildContributorPanel(int width, bool ansi)
        {
            if (_contributors.Length == 0) return null;
            var c = _contributors[(_contributorStart + (int)(_clock.Elapsed.TotalSeconds / ContributorSeconds)) % _contributors.Length];
            string url = ContributorSite + c.GitHub.ToLowerInvariant();
            var panel = new PanelContent { Title = "Featured contributor" };

            // The name on the left and the handle on the right, both a hyperlink to the person's page.
            string handle = "@" + c.GitHub;
            if (width - handle.Length - 2 < 8) handle = string.Empty;
            int nameRoom = handle.Length > 0 ? width - handle.Length - 2 : width;
            string name = c.Name.Length <= nameRoom ? c.Name : c.Name.Substring(0, Math.Max(0, nameRoom - 1)) + (Unicode ? "…" : ".");
            panel.Lines.Add(new LineBuilder(ansi).AddLink(name, url, "1").Add(new string(' ', Math.Max(0, width - name.Length - handle.Length))).AddLink(handle, url, "36").Build());

            // What the person did. A count of nothing is left out, not shown as 0.
            var parts = new List<string>();
            if (c.Tests > 0) parts.Add(Count(c.Tests, "test"));
            if (c.Improvements > 0) parts.Add(Count(c.Improvements, "improvement"));
            string since = c.Since > 0 ? "since " + N(c.Since) : string.Empty;
            string did;
            if (parts.Count == 0) did = since.Length > 0 ? "Contributor " + since : string.Empty;
            else did = string.Join(Unicode ? " · " : ", ", parts) + (since.Length > 0 ? (Unicode ? " · " : ", ") + since : string.Empty);
            if (did.Length > 0) panel.Lines.Add(Truncate(new LineBuilder(ansi).Add(did, "2").Build(), width, ansi));
            return panel;
        }

        // ------------------------------------------------------------------ the results so far

        /// <summary>
        /// The Totals panel: one bar across the panel, split by result in the share each has of the tests that
        /// finished, and under it the count and share of each result that has tests.
        /// </summary>
        private PanelContent BuildTotalsPanel(int width, bool ansi)
        {
            if (!_running && _sequence.Count == 0) return null;
            int[] counts = { _passed, _failed, _error, _investigate, _skipped + _other };
            int total = 0;
            foreach (int count in counts) total += count;
            var panel = new PanelContent { Title = "Results", Badge = N(total) + " of " + N(_total) };
            panel.Lines.Add(TotalsBar(counts, total, Math.Max(1, width), ansi));
            panel.Lines.Add(TotalsLegend(counts, total, width, ansi));
            return panel;
        }

        /// <summary>
        /// Where each part of the bar ends, in cells, or null before there are results. A part that would be
        /// too thin to see gets a twenty-fifth of the bar (a cell at least), so that one failure among hundreds
        /// of passed tests still shows.
        /// </summary>
        private static double[] TotalsEnds(int[] counts, int total, int width)
        {
            if (total <= 0) return null;
            double least = Math.Max(0.04, 1.0 / width);
            var share = new double[counts.Length];
            double sum = 0;
            for (int i = 0; i < counts.Length; i++)
            {
                share[i] = counts[i] > 0 ? Math.Max(least, (double)counts[i] / total) : 0;
                sum += share[i];
            }
            var ends = new double[counts.Length];
            double at = 0;
            for (int i = 0; i < counts.Length; i++)
            {
                at += share[i] / sum * width;
                ends[i] = at;
            }
            ends[counts.Length - 1] = width;
            return ends;
        }

        /// <summary>
        /// The bar. Where two results meet inside a cell, the cell is a partial block in the colour of the left
        /// one on a background in the colour of the right one, so the split is exact to an eighth of a cell.
        /// Without colour each result has its own shade; without Unicode its own character.
        /// </summary>
        private Line TotalsBar(int[] counts, int total, int width, bool ansi)
        {
            double[] ends = TotalsEnds(counts, total, width);
            var b = new LineBuilder(ansi);
            if (ends == null)
            {
                return b.Add(new string(Unicode ? (ansi ? '█' : '░') : '.', width), TotalsFg[TotalsEmpty]).Build();
            }
            string shades = Unicode ? "█▓▒▒░" : "#x!?-";
            int part = 0;
            for (int x = 0; x < width; x++)
            {
                while (part < ends.Length - 1 && ends[part] <= x) part++;
                // The next part that has tests, when this one ends inside the cell.
                int next = part;
                if (ends[part] < x + 1)
                {
                    next = part + 1;
                    while (next < ends.Length - 1 && ends[next] <= ends[part]) next++;
                }
                int eighths = next == part ? 8 : (int)Math.Round((ends[part] - x) * 8);
                if (eighths >= 8 || next == part) b.Add(ansi ? "█" : shades[part].ToString(), TotalsFg[part]);
                else if (eighths <= 0) b.Add(ansi ? "█" : shades[next].ToString(), TotalsFg[next]);
                else if (ansi && Unicode) b.Add(Eighths[eighths - 1].ToString(), TotalsFg[part] + ";" + TotalsBg[next]);
                else b.Add(shades[eighths >= 4 ? part : next].ToString(), null);
            }
            return b.Build();
        }

        /// <summary>
        /// The counts under the bar: each result that has tests, with its name and its share when they fit, in
        /// fewer words when they do not.
        /// </summary>
        private Line TotalsLegend(int[] counts, int total, int width, bool ansi)
        {
            if (total <= 0) return new LineBuilder(ansi).Add("Waiting for results" + Ellipsis(), "2").Build();
            string[] marks = { Ok, Bad, "!", "?", Dash };
            string[] names = { "passed", "failed", counts[2] == 1 ? "error" : "errors", "investigate", "skipped" };
            // From the most words to the fewest: names and shares, names, shares, counts alone.
            for (int form = 0; form < 4; form++)
            {
                var b = new LineBuilder(ansi);
                string gap = form < 3 ? "   " : "  ";
                for (int i = 0; i < counts.Length; i++)
                {
                    if (counts[i] == 0) continue;
                    if (b.Length > 0) b.Add(gap);
                    b.Add(marks[i] + " " + N(counts[i]), TotalsFg[i]);
                    if (form < 2) b.Add(" " + names[i], i < 4 ? null : "2");
                    if (form == 0 || form == 2) b.Add(" " + N((int)Math.Round(100.0 * counts[i] / total)) + "%", "2");
                }
                if (b.Length <= width || form == 3) return Truncate(b.Build(), Math.Max(1, width), ansi);
            }
            return new LineBuilder(ansi).Build();
        }
    }
}
