using System;
using System.Collections.Generic;

namespace Maester.Engine
{
    /// <summary>
    /// The boxed layout of the main column, on a console that has the rows for it: the phases on a track, and
    /// every other part of the main column a box like the panels of the right column, with its name in the top
    /// border and a colour for what it holds.
    ///
    ///   Track     the phases as stops on a line (BuildTrack). The line after the phase of the tests fills as
    ///             tests finish; the line after another phase that works has a dot that runs along it. Under
    ///             the stops, their times, how far the tests are or what the phase is doing, and the counts.
    ///   Products  one lane per product, in a green box.
    ///   Pace      the graph of how long each test took, when the band at the top has no room for it.
    ///   Tests     one block per test.
    ///   Running   one line per running test, and under a dashed line the tests that finished, newest first,
    ///             in a teal box. It takes the rows down to the insight panels, or to the bottom.
    ///
    /// The boxes cost their borders: about four rows more than the plain lines, which come out of the list
    /// of finished tests. A console with fewer rows, or a narrower one, keeps the plain lines.
    ///
    /// The dashboard moves where work moves, on the tick: a pulse runs along the bar of each product that has
    /// tests running and along the finished part of the track, a dot runs along the line of a phase that works,
    /// and a block that just got its result is bright for a moment. A frame changes a few cells for it, which
    /// the frame of the tick writes as lines.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const int BoxedLeastRows = 34;
        private const int BoxedLeastWidth = 78;
        // How many ticks a block that just got its result stays bright.
        private const int FreshTicks = 4;
        private const string FreshCell = "1;97";
        private const string WaitingCell = "38;5;238";
        private const string PulseHead = "1;38;5;194";
        private const string PulseTrail = "38;5;151";
        // The lines between the stops of the track: eight columns, and at least twelve for the tests.
        private const int TrackLineLength = 8;
        private const int TrackLineLeast = 12;
        // The colours of the boxes, by what they hold: products green, running tests teal. The others are grey.
        private const string ProductsBorder = "38;5;71";
        private const string RunningBorder = "38;5;73";

        private enum SegmentState { Waiting, Active, Done }

        // The phase that was current when the tests started, or -1.
        private int _testPhase = -1;
        // The tick on which each finished test got its result, in the order of _sequence.
        private readonly List<int> _sequenceTicks = new List<int>();

        /// <summary>
        /// Moves the dashboard where work moves: a pulse along busy bars, a bright block for a new result, a
        /// block that moves through a phase that has no count. Only with colour, and only on the ticks of the
        /// dashboard. On by default.
        /// </summary>
        public bool Animate { get; set; } = true;

        private bool Flowing { get { return Animate && Ansi && _ticker != null; } }

        /// <summary>Whether the main column has the rows and the columns for its boxes.</summary>
        private static bool Boxed(int max, int rows)
        {
            return rows >= BoxedLeastRows && max >= BoxedLeastWidth;
        }

        private int CurrentPhaseIndex()
        {
            for (int i = 0; i < _phases.Count; i++)
            {
                if (!_phases[i].Done && _phases[i].Clock != null) return i;
            }
            return -1;
        }

        /// <summary>The phase in which the tests run: the one that was current when they started, else the first whose name says so.</summary>
        private int TestPhaseIndex()
        {
            if (_testPhase >= 0 && _testPhase < _phases.Count) return _testPhase;
            for (int i = 0; i < _phases.Count; i++)
            {
                if (_phases[i].Name != null && _phases[i].Name.IndexOf("test", StringComparison.OrdinalIgnoreCase) >= 0) return i;
            }
            return -1;
        }

        // ------------------------------------------------------------------ the main column

        /// <summary>The main column with its boxes, or null when the rows are too few for them next to what it has to show.</summary>
        private List<Line> BuildBoxedMain(int max, int rows, bool ansi)
        {
            bool tests = _running || _total > 0;
            int boxWidth = max - 1;
            int inner = boxWidth - 4;
            bool band = (tests || OutputTimed) && _runLogo != null && rows >= RunBandLeastRows && max >= _runLogoWidth + 3 + RunBandLeastGraph;
            var track = _phases.Count > 0 || tests ? BuildTrack(max - 1, ansi) : new List<Line>();
            bool output = _outputTitle != null;

            var screen = new List<Line>();
            if (band) screen.AddRange(BuildRunBand(max, ansi));
            else if (tests) screen.AddRange(BuildRunHeader(max, null, ansi));
            else screen.AddRange(BuildOpeningHeader(max, rows, track.Count + 3 + (output ? OutputOpeningRows : 0), ansi));
            if (_info != null) screen.Add(BuildInfoLine(max, ansi));
            screen.Add(Blank());
            if (track.Count > 0)
            {
                screen.AddRange(track);
                screen.Add(Blank());
            }
            // Before the tests start, the output of the work that runs (an instance source) has the rows under the phases.
            if (!tests)
            {
                if (output)
                {
                    // The work's groups and result blocks, when its progress has them, over its box.
                    screen.AddRange(BuildOutputView(boxWidth, rows - screen.Count, ansi));
                    screen.AddRange(BuildOutputBox(boxWidth, rows - screen.Count, ansi));
                }
                return Fit(screen, rows);
            }

            var skippedLanes = SkippedLanes();
            int lanesWanted = Lanes.Count - skippedLanes.Count + (skippedLanes.Count > 0 ? 1 : 0);
            // While tests run: one line per running test, and a dashed line over the finished ones.
            var tail = _running ? BuildWorkerLines(inner, string.Empty, ansi) : new List<Line>();
            int runChrome = _running ? 3 : 2;
            bool chart = PanelShown(ResultsPanel);
            // The output box of a test that writes one has its rows set aside, as the running tests have.
            int outputRows = output ? OutputTestRows : 0;
            runChrome += outputRows;
            int top = screen.Count;
            // The boxes cost rows. When they would leave no room for what the plain lines have room for (a
            // row of insight panels and two running tests, or one running test), the plain lines are drawn.
            int least = top + (lanesWanted > 0 ? lanesWanted + 2 : 0) + (chart ? 3 : 0) + runChrome + (_insights ? InsightRows + 4 : 1);
            if (least > rows) return null;

            // The insight panels keep their place, as in the plain layout: both rows of them on a screen that
            // has the rows, or one, with three finished tests over them, or one row and no finished tests.
            int reserve = 0;
            int recentKept = RecentLeast;
            if (_insights && _running)
            {
                for (int tier = 0; tier <= InsightLayout.Length && reserve == 0; tier++)
                {
                    bool last = tier == InsightLayout.Length;
                    int panelRows = last ? 1 : InsightLayout.Length - tier;
                    int kept = panelRows * (InsightRows + 2) + (last ? 0 : RecentLeast);
                    int most = rows - top - (lanesWanted > 0 ? lanesWanted + 2 : 0) - (chart ? 3 : 0) - runChrome - kept;
                    if (most < (last ? 2 : 1 + RecentLeast)) continue;
                    reserve = kept;
                    if (last) recentKept = 0;
                    if (tail.Count > most) LeaveMoreRunning(tail, most, ansi);
                }
            }

            // Products take the rows they need; when there are not enough, the ones with work left stay.
            int room = rows - top - tail.Count - runChrome - 2;
            if (lanesWanted > 0 && room >= 2)
            {
                var lanes = BuildLaneRows(inner, room, string.Empty, skippedLanes, ansi);
                var products = new PanelContent { Title = LanesTitle, Badge = _outputLanes != null ? N(_outputLanes.Count) : Count(_lanes.Count, "product"), Colour = ProductsBorder, TitleColour = ProductsBorder, Lines = lanes };
                screen.AddRange(Indent(Box(products, boxWidth, ansi)));
            }

            // Without the band the Pace graph has a box of its own, when there are rows for it.
            int free = rows - screen.Count - tail.Count - runChrome;
            if (!band && PanelShown(PacePanel) && free >= 12)
            {
                var pace = BuildPaceSection(inner, Math.Max(PaceGraphLeast, Math.Min(PaceGraphMost, free - 10)), string.Empty, ansi);
                screen.AddRange(Indent(Box(new PanelContent { Title = "Pace", Lines = pace }, boxWidth, ansi)));
                free = rows - screen.Count - tail.Count - runChrome;
            }

            var blocks = BuildResultsChart(inner, free - reserve - 2, string.Empty, ansi);
            if (blocks.Count > 0)
            {
                screen.AddRange(Indent(Box(new PanelContent { Title = "Tests", Badge = N(FinishedCount()) + " of " + N(_total), Lines = blocks }, boxWidth, ansi)));
            }

            if (output && rows - screen.Count >= runChrome + 1) screen.AddRange(BuildOutputBox(boxWidth, outputRows, ansi));
            runChrome -= outputRows;

            // The running tests and the finished ones take the rows down to the insight panels.
            int left = rows - screen.Count;
            var insights = BuildInsights(max, left - runChrome - tail.Count - Math.Min(recentKept, _recent.Count), ansi);
            int height = left - insights.Count;
            if (height < runChrome + 1) return Fit(screen, rows);
            // Inside the box: the running tests, and under a dashed line the finished ones, when there are
            // rows for the line and one of them at least. After the tests, the finished ones alone.
            int inside = height - 2;
            if (tail.Count > inside) LeaveMoreRunning(tail, inside, ansi);
            var lines = new List<Line>(tail);
            bool rule = _running && _recent.Count > 0 && inside - tail.Count >= 2;
            if (rule) lines.Add(new Line { Text = string.Empty, Plain = string.Empty, Rule = "Finished", Dashed = true });
            if (rule || !_running) lines.AddRange(BuildRecent(inner, inside - lines.Count, string.Empty, ansi));
            while (lines.Count < inside) lines.Add(Blank());
            var running = new PanelContent
            {
                Title = _running ? "Running" : "Finished",
                Badge = _running ? Count(_workers.Count, "test") : N(FinishedCount()) + " of " + N(_total),
                Colour = RunningBorder,
                TitleColour = RunningBorder,
                Lines = lines
            };
            screen.AddRange(Indent(Box(running, boxWidth, ansi)));
            screen.AddRange(insights);
            return Fit(screen, rows);
        }

        private static Line Blank()
        {
            return new Line { Text = string.Empty, Plain = string.Empty };
        }

        private static List<Line> Fit(List<Line> lines, int rows)
        {
            if (lines.Count > rows) lines.RemoveRange(rows, lines.Count - rows);
            return lines;
        }

        /// <summary>Boxes start in the second column, as the insight panels under them do.</summary>
        private static List<Line> Indent(List<Line> lines)
        {
            var result = new List<Line>(lines.Count);
            foreach (var l in lines) result.Add(new Line { Text = " " + l.Text, Plain = " " + l.Plain });
            return result;
        }

        /// <summary>Keeps the first running tests that fit in <paramref name="rows"/> rows, and says how many more there are.</summary>
        private void LeaveMoreRunning(List<Line> tail, int rows, bool ansi)
        {
            if (rows < 1 || tail.Count <= rows) return;
            int more = tail.Count - (rows - 1);
            tail.RemoveRange(rows - 1, more);
            tail.Add(new LineBuilder(ansi).Add("   " + Ellipsis() + " and " + N(more) + " more running", "2").Build());
        }

        // ------------------------------------------------------------------ the track of the phases

        /// <summary>
        /// The phases as stops on a line, in two rows. The first has the stops and the lines between them: the
        /// line after a phase that is done is solid, the line after one still to come is dotted. The line after
        /// the phase of the tests fills as they finish, with an amber dot at its front and a pulse along what is
        /// done; the line after another phase that works has a dot that runs along it. The second row has, under
        /// each stop that started, its time, how far the tests are under theirs, what the phase is doing under
        /// one that works, and at the right the counts so far. <paramref name="width"/> is the columns after the
        /// first, which is blank.
        /// </summary>
        private List<Line> BuildTrack(int width, bool ansi)
        {
            var names = new List<string>();
            if (_phases.Count == 0) names.Add("Tests");
            else foreach (var p in _phases) names.Add(p.Name);
            int count = names.Count;
            int test = _phases.Count > 0 ? TestPhaseIndex() : 0;
            var states = new SegmentState[count];
            for (int i = 0; i < count; i++) states[i] = SegmentStateOf(i);
            // While tests run their phase works, whichever phase the caller marked.
            if (_running && test >= 0) states[test] = SegmentState.Active;

            // A line after each stop but the last; after the last too when it is the phase of the tests, which
            // has to have a line to fill.
            var stops = new Line[count];
            int used = 0;
            for (int i = 0; i < count; i++)
            {
                stops[i] = StopLabel(names[i], states[i], ansi);
                used += stops[i].Plain.Length;
            }
            int lines = count - 1 + (test == count - 1 ? 1 : 0);
            var lengths = TrackLengths(lines, test, width - used - 2 * lines);

            var top = new LineBuilder(ansi).Add(" ");
            var at = new int[count];
            for (int i = 0; i < count; i++)
            {
                at[i] = top.Length;
                top.AddLine(stops[i]);
                if (i < lines)
                {
                    top.Add(" ");
                    AddTrackLine(top, states[i], i == test, lengths[i]);
                    if (i < count - 1) top.Add(" ");
                }
            }

            // The counts keep their place at the right: when the row is too long for them, the time left goes
            // first, then the end of what a phase is doing.
            Line counts = null;
            if (_started)
            {
                var c = new LineBuilder(ansi);
                AddCounts(c, _passed, _failed, _error, _investigate, _skipped);
                counts = c.Build();
            }
            int full = width + 1;
            int room = counts != null ? full - counts.Plain.Length - 3 : full;
            Line under = BuildTrackTimes(at, states, test, true, room, ansi);
            if (under.Plain.Length > room) under = BuildTrackTimes(at, states, test, false, room, ansi);
            if (under.Plain.Length > room)
            {
                // What a phase is doing goes before the counts, which the right column and the products have too.
                int current = CurrentPhaseIndex();
                if (current >= 0 && current != test && _status != null)
                {
                    under = Truncate(BuildTrackTimes(at, states, test, false, full, ansi), full, ansi);
                    counts = null;
                }
                else
                {
                    under = Truncate(under, room, ansi);
                }
            }
            var sub = new LineBuilder(ansi).AddLine(under);
            if (counts != null) sub.Add(new string(' ', full - counts.Plain.Length - sub.Length)).AddLine(counts);
            return new List<Line> { Truncate(top.Build(), width + 1, ansi), Truncate(sub.Build(), width + 1, ansi) };
        }

        private string Dot { get { return Unicode ? " · " : " - "; } }

        /// <summary>
        /// The row under the stops: under each stop that started its time, under the tests how far they are
        /// (and the time left, with <paramref name="eta"/>), under another phase that works what it is doing.
        /// Each starts under the name of its stop, or further left so that it ends by <paramref name="limit"/>,
        /// but never on the one before it.
        /// </summary>
        private Line BuildTrackTimes(int[] at, SegmentState[] states, int test, bool eta, int limit, bool ansi)
        {
            var sub = new LineBuilder(ansi);
            for (int i = 0; i < states.Length; i++)
            {
                // The tests have the clock of the run when no phase was marked for them.
                var clock = i < _phases.Count ? _phases[i].Clock : null;
                if (clock == null && i == test && _started) clock = _clock;
                if (states[i] == SegmentState.Waiting || clock == null) continue;
                var piece = new LineBuilder(ansi).Add(Short(clock.Elapsed), "2");
                if (i == test && _total > 0)
                {
                    int done = FinishedCount();
                    piece.Add(Dot + N(done) + "/" + N(_total));
                    if (states[i] != SegmentState.Done)
                    {
                        piece.Add(Dot + N((int)Math.Min(100L, 100L * done / _total)) + "%");
                        if (eta && done >= 5 && done < _total) piece.Add(Dot + "ETA " + Time(TimeSpan.FromTicks(clock.Elapsed.Ticks / done * (_total - done))));
                    }
                }
                else if (states[i] == SegmentState.Active && _status != null)
                {
                    piece.Add(Dot + _status + Ellipsis(), "2");
                }
                int start = Math.Max(sub.Length > 0 ? sub.Length + 2 : 0, Math.Min(at[i] + 2, limit - piece.Length));
                sub.Add(new string(' ', start - sub.Length)).AddLine(piece.Build());
            }
            return sub.Build();
        }

        private SegmentState SegmentStateOf(int index)
        {
            if (_phases.Count == 0) return _running ? SegmentState.Active : (_started ? SegmentState.Done : SegmentState.Waiting);
            var p = _phases[index];
            if (p.Done) return SegmentState.Done;
            return p.Clock != null ? SegmentState.Active : SegmentState.Waiting;
        }

        /// <summary>A stop: the mark of its state and the name of the phase.</summary>
        private Line StopLabel(string name, SegmentState state, bool ansi)
        {
            var b = new LineBuilder(ansi);
            if (state == SegmentState.Done) b.Add(Ok, "32").Add(" " + name, "2");
            else if (state == SegmentState.Active) b.Add(Unicode ? "●" : "*", Amber).Add(" " + name, "1");
            else b.Add((Unicode ? "○" : "o") + " " + name, "2");
            return b.Build();
        }

        /// <summary>
        /// The lengths of the lines between the stops in <paramref name="room"/> columns: the line after the
        /// phase of the tests takes what the others leave, eight columns each, fewer on a narrow console.
        /// Without a phase of the tests they share the room.
        /// </summary>
        private static int[] TrackLengths(int lines, int test, int room)
        {
            var lengths = new int[lines];
            if (lines == 0) return lengths;
            if (test < 0 || test >= lines)
            {
                for (int i = 0; i < lines; i++) lengths[i] = Math.Max(1, room / lines + (i < room % lines ? 1 : 0));
                return lengths;
            }
            int others = lines - 1;
            int shortLength = TrackLineLength;
            while (others > 0 && shortLength > 3 && room - shortLength * others < TrackLineLeast) shortLength--;
            for (int i = 0; i < lines; i++) lengths[i] = i == test ? Math.Max(1, room - shortLength * others) : shortLength;
            return lengths;
        }

        /// <summary>
        /// The line after a phase. Done: solid. To come: dotted. The phase of the tests: filled as they finish,
        /// with a pulse along what is done and an amber dot at its front. Another phase that works: a dot that
        /// runs along the line, on the ticks.
        /// </summary>
        private void AddTrackLine(LineBuilder b, SegmentState state, bool tests, int length)
        {
            char solid = Unicode ? '━' : '=';
            char dotted = Unicode ? '┄' : '.';
            if (state == SegmentState.Done)
            {
                b.Add(new string(solid, length), "32");
                return;
            }
            if (state == SegmentState.Waiting)
            {
                b.Add(new string(dotted, length), WaitingCell);
                return;
            }
            if (tests)
            {
                int filled = _total > 0 ? (int)Math.Min(length - 1, (long)(length - 1) * FinishedCount() / _total) : 0;
                if (Flowing && filled >= 3) AddPulsed(b, solid, filled, _tick * 2 % (filled + 14), "32");
                else b.Add(new string(solid, filled), "32");
                b.Add(Unicode ? "●" : "*", "1;" + Amber).Add(new string(dotted, length - filled - 1), WaitingCell);
                return;
            }
            if (!Flowing)
            {
                b.Add(new string(dotted, length), Amber);
                return;
            }
            // A dot with a short tail that runs along the line, from the stop to the next.
            int head = _tick % (length + 3);
            int from = Math.Max(0, head - 2);
            b.Add(new string(dotted, Math.Min(from, length)), WaitingCell);
            for (int k = from; k <= head && k < length; k++)
            {
                if (k == head) b.Add(Unicode ? "●" : "*", "1;" + Amber);
                else b.Add(k == head - 1 ? (Unicode ? "•" : "+") : (Unicode ? "·" : "."), Amber);
            }
            if (head + 1 < length) b.Add(new string(dotted, length - head - 1), WaitingCell);
        }

        /// <summary>
        /// <paramref name="count"/> cells of <paramref name="cell"/> with a pulse in them: a bright cell at
        /// <paramref name="head"/> and three lighter ones behind it. A head past the end leaves its trail.
        /// </summary>
        private static void AddPulsed(LineBuilder b, char cell, int count, int head, string colour)
        {
            int trailFrom = Math.Max(0, Math.Min(count, head - 3));
            int trailTo = Math.Max(trailFrom, Math.Min(count, head));
            b.Add(new string(cell, trailFrom), colour).Add(new string(cell, trailTo - trailFrom), PulseTrail);
            if (head < count)
            {
                b.Add(cell.ToString(), PulseHead);
                b.Add(new string(cell, count - head - 1), colour);
            }
        }

        // ------------------------------------------------------------------ products, running tests

        /// <summary>The lanes whose tests were all skipped: they share one line, by name and number of tests.</summary>
        private List<Lane> SkippedLanes()
        {
            var skipped = new List<Lane>();
            foreach (var l in Lanes)
            {
                if (SkippedCount(l) > 0) skipped.Add(l);
            }
            return skipped;
        }

        /// <summary>
        /// One line per product, in <paramref name="room"/> rows at most: when there are not enough, the
        /// products that are running or have the most tests left stay, and a line says how many more there
        /// are. The products whose tests were all skipped share the last line.
        /// </summary>
        private List<Line> BuildLaneRows(int max, int room, string lead, List<Lane> skippedLanes, bool ansi)
        {
            var lines = new List<Line>();
            var all = Lanes;
            var shown = new List<Lane>(all);
            shown.RemoveAll(l => skippedLanes.Contains(l));
            int skippedLine = skippedLanes.Count > 0 ? 1 : 0;
            room -= skippedLine;
            int hidden = 0;
            if (shown.Count > room)
            {
                shown.Sort((a, b) =>
                {
                    int byRunning = (b.Running > 0 ? 1 : 0).CompareTo(a.Running > 0 ? 1 : 0);
                    return byRunning != 0 ? byRunning : (b.Total - b.Done).CompareTo(a.Total - a.Done);
                });
                hidden = shown.Count - (room - 1);
                shown.RemoveRange(room - 1, hidden);
                shown.Sort((a, b) => all.IndexOf(a).CompareTo(all.IndexOf(b)));
            }
            int nameWidth = 8;
            foreach (var l in shown) nameWidth = Math.Max(nameWidth, Math.Min(18, l.Name.Length));
            // Up to the standard width the bars are at most 24 columns; a wider column gives them the extra.
            int barWidth = Math.Max(8, Math.Min(24, max - nameWidth - 52) + Math.Max(0, max - (MainWidth - 1)));
            foreach (var l in shown)
            {
                bool active = l.Done > 0 || l.Running > 0;
                var b = new LineBuilder(ansi).Add(lead).Add(Fit(l.Name, nameWidth).PadRight(nameWidth + 1), active ? "1" : "2");
                AddBar(b, l.Done, l.Total, barWidth, l.Running > 0 ? all.IndexOf(l) : -1);
                b.Add((" " + N(l.Done) + "/" + N(l.Total)).PadLeft(9) + "  ", "2");
                if (l.Done > 0)
                {
                    b.Add((Ok + " " + N(l.Passed)).PadRight(7), "32");
                    b.Add((Bad + " " + N(l.Failed)).PadRight(6), l.Failed > 0 ? "31" : "2");
                    b.Add(("! " + N(l.Error)).PadRight(5), l.Error > 0 ? "33" : "2");
                    b.Add(("? " + N(l.Investigate)).PadRight(5), l.Investigate > 0 ? "35" : "2");
                }
                else
                {
                    b.Add(new string(' ', 23));
                }
                if (l.Running > 0) b.Add(" " + N(l.Running) + " running", Amber);
                else if (!string.IsNullOrEmpty(l.Note)) b.Add(" " + l.Note, "2");
                else if (l.Done == 0 && l.Total > 0 && _running) b.Add(" waiting", "2");
                lines.Add(Truncate(b.Build(), max, ansi));
            }
            if (hidden > 0) lines.Add(new LineBuilder(ansi).Add(lead + Ellipsis() + " and " + N(hidden) + " more", "2").Build());
            if (skippedLine > 0)
            {
                var skippedNames = new List<string>();
                foreach (var l in skippedLanes) skippedNames.Add(l.Name + " (" + N(SkippedCount(l)) + ")");
                string dot = Unicode ? " · " : ", ";
                lines.Add(Truncate(new LineBuilder(ansi).Add(lead + Dash + " Skipped  ", "2").Add(string.Join(dot, skippedNames), "2").Build(), max, ansi));
            }
            return lines;
        }

        /// <summary>One line per running test, or the status of the run when no test is running.</summary>
        private List<Line> BuildWorkerLines(int max, string lead, bool ansi)
        {
            var lines = new List<Line>();
            foreach (var w in _workers)
            {
                string time = Short(w.Clock.Elapsed).PadLeft(7);
                var b = new LineBuilder(ansi).Add(lead + Spinner() + " ", "36").Add(FitId(w.Id) + " ", "1").Add(w.Title);
                var cut = Truncate(b.Build(), max - time.Length - 1, ansi);
                string gap = new string(' ', Math.Max(1, max - time.Length - cut.Plain.Length));
                lines.Add(new Line { Text = cut.Text + gap + (ansi ? Esc + "2m" + time + Esc + "0m" : time), Plain = cut.Plain + gap + time });
            }
            if (_workers.Count == 0) lines.Add(new LineBuilder(ansi).Add(lead + Spinner() + " ", "36").Add((_status ?? "Starting the next test") + Ellipsis(), "2").Build());
            return lines;
        }

        /// <summary>Whether a test among the finished ones from <paramref name="first"/> to <paramref name="end"/> got its result a moment ago.</summary>
        private bool Fresh(int first, int end)
        {
            if (!Flowing) return false;
            for (int i = Math.Max(first, end - 8); i < end && i < _sequenceTicks.Count; i++)
            {
                if (_tick - _sequenceTicks[i] < FreshTicks) return true;
            }
            return false;
        }
    }
}
