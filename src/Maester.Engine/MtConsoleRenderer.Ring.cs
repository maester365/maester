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
    /// Two panels of the right column: Ring, the results so far as a ring chart, and Contributor, one of the
    /// people who built Maester, a different one every twenty seconds.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        // The ring is drawn on a grid of square pixels, two to a character cell (an upper and a lower half
        // block): ten by ten pixels in five rows of ten cells.
        private const int RingRows = 5;
        private const double RingOuter = 5.0;
        private const double RingInner = 2.5;
        private const int RingEmpty = 5;
        private const string ContributorSite = "https://maester.dev/contributors/";

        // Passed, failed, error, investigate, skipped, and the ring before there are results.
        private static readonly string[] RingFg = { "32", "31", "33", "35", "38;5;244", "38;5;238" };
        private static readonly string[] RingBg = { "42", "41", "43", "45", "48;5;244", "48;5;238" };

        private MtContributor[] _contributors = new MtContributor[0];
        private int _contributorStart;

        /// <summary>
        /// The people of the Featured contributor panel. One is shown at a time, for twenty seconds each,
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
            var c = _contributors[(_contributorStart + (int)(_clock.Elapsed.TotalSeconds / 20)) % _contributors.Length];
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

        // ------------------------------------------------------------------ the ring

        private PanelContent BuildRingPanel(int width, bool ansi)
        {
            if (!_running && _sequence.Count == 0) return null;
            int[] counts = { _passed, _failed, _error, _investigate, _skipped + _other };
            int total = 0;
            foreach (int count in counts) total += count;
            var panel = new PanelContent { Title = "Results", Badge = N(total) + " of " + N(_total) };

            // Without Unicode there are no half blocks to draw a ring with: the counts alone.
            if (!Unicode)
            {
                panel.Lines.AddRange(RingLegend(counts, total, width, ansi));
                return panel;
            }
            // In the middle of the ring: the share of the tests with a verdict that passed.
            int judged = _passed + _failed + _error + _investigate;
            string centre = judged > 0 ? N((int)Math.Round(100.0 * _passed / judged)) + "%" : string.Empty;
            double[] ends = RingShares(counts, total);
            var legend = RingLegend(counts, total, width - 2 * RingRows - 3, ansi);
            for (int row = 0; row < RingRows; row++)
            {
                var ring = RingRow(row, ends, centre, ansi);
                panel.Lines.Add(new Line { Text = ring.Text + "   " + legend[row].Text, Plain = ring.Plain + "   " + legend[row].Plain });
            }
            return panel;
        }

        /// <summary>
        /// Where each slice of the ring ends, as a part of a full turn, or null before there are results. A slice
        /// that would be too thin to see gets a twenty-fifth of the ring, so that one failure among hundreds of
        /// passed tests still shows.
        /// </summary>
        private static double[] RingShares(int[] counts, int total)
        {
            if (total <= 0) return null;
            const double least = 0.04;
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
                at += share[i] / sum;
                ends[i] = at;
            }
            return ends;
        }

        /// <summary>The slice a pixel of the ring belongs to, or -1 for a pixel outside the ring or in its hole.</summary>
        private static int RingPixel(int px, int py, double[] ends)
        {
            double dx = px + 0.5 - RingRows;
            double dy = py + 0.5 - RingRows;
            double distance = Math.Sqrt(dx * dx + dy * dy);
            if (distance > RingOuter || distance < RingInner) return -1;
            if (ends == null) return RingEmpty;
            // Clockwise from twelve o'clock.
            double turn = Math.Atan2(dx, -dy) / (2 * Math.PI);
            if (turn < 0) turn += 1;
            int slice = 0;
            while (slice < ends.Length - 1 && turn >= ends[slice]) slice++;
            return slice;
        }

        /// <summary>
        /// One row of the ring: for each cell an upper and a lower pixel. Two pixels of different slices make an
        /// upper half block in the colour of the upper one on a background in the colour of the lower one.
        /// </summary>
        private Line RingRow(int row, double[] ends, string centre, bool ansi)
        {
            int columns = 2 * RingRows;
            var b = new LineBuilder(ansi);
            string label = row == RingRows / 2 ? centre.PadLeft(4) : null;
            for (int x = 0; x < columns; x++)
            {
                int upper = RingPixel(x, 2 * row, ends);
                int lower = RingPixel(x, 2 * row + 1, ends);
                if (upper < 0 && lower < 0)
                {
                    // The hole: the percentage goes in the four cells in the middle of the middle row.
                    int at = x - (RingRows - 2);
                    bool text = label != null && at >= 0 && at < label.Length;
                    b.Add(text ? label[at].ToString() : " ", text ? "1" : null);
                }
                else if (lower < 0) b.Add("▀", RingFg[upper]);
                else if (upper < 0) b.Add("▄", RingFg[lower]);
                else if (upper == lower || !ansi) b.Add("█", RingFg[upper]);
                else b.Add("▀", RingFg[upper] + ";" + RingBg[lower]);
            }
            return b.Build();
        }

        /// <summary>The counts next to the ring, one result to a line, with its share of the tests when there is room.</summary>
        private List<Line> RingLegend(int[] counts, int total, int width, bool ansi)
        {
            string[] marks = { Ok, Bad, "!", "?", Dash };
            string[] names = { "passed", "failed", counts[2] == 1 ? "error" : "errors", "investigate", "skipped" };
            string[] colours = { "32", "31", "33", "35", "2" };
            int digits = 1;
            foreach (int count in counts) digits = Math.Max(digits, N(count).Length);
            bool shares = width >= digits + 20;
            var lines = new List<Line>();
            for (int i = 0; i < counts.Length; i++)
            {
                bool any = counts[i] > 0;
                var b = new LineBuilder(ansi).Add(marks[i] + " " + N(counts[i]).PadLeft(digits), any ? colours[i] : "2").Add(" " + names[i], any && i < 4 ? null : "2");
                if (shares)
                {
                    string share = total > 0 ? N((int)Math.Round(100.0 * counts[i] / total)) + "%" : string.Empty;
                    b.Add(new string(' ', Math.Max(1, width - b.Length - share.Length))).Add(share, "2");
                }
                lines.Add(Truncate(b.Build(), Math.Max(1, width), ansi));
            }
            return lines;
        }
    }
}
