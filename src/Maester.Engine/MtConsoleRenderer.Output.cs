using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Text;

namespace Maester.Engine
{
    /// <summary>
    /// The output box of the dashboard: what a long-running test writes while it works, such as the log of a
    /// tool it runs in another process (the Zero Trust Assessment pack runs Microsoft's assessment that way).
    /// That process cannot write to the console itself while the dashboard has the screen, so the test hands
    /// its lines to the renderer, which shows them in a box in the main column that scrolls as they come in.
    ///
    /// StartOutput opens the box with a title, WriteOutput adds lines, or sets the line of progress that is
    /// pinned at the bottom of the box, StopOutput closes it. SetOutputProgress gives the box a header with where
    /// the work is (its stage, a bar of the items done, what it is working on) and AddOutputError lists the
    /// errors the work reported under it, so the progress a tool keeps can be shown without parsing its log. Before the tests start (a family's instance source runs then) the box
    /// takes the rows under the phases; while tests run it sits between the result blocks and the running tests.
    /// Only the dashboard draws it: in the compact layout the caller writes the lines to the scrollback.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        // The lines kept for the box: more than any console has rows for.
        private const int OutputKept = 500;
        // The rows of the box with its border: at least three lines in it, and while tests run ten rows.
        private const int OutputLeastRows = 5;
        // With a header of progress the box has four more rows while tests run.
        private int OutputTestRows { get { return _outputProgress != null && _outputProgress.Items.Length > 0 ? 18 : _outputProgress != null || _outputErrors.Count > 0 ? 14 : 10; } }
        // The errors kept for the header, of which it shows the newest two.
        private const int OutputErrorsKept = 20;
        // The rows the banner leaves the box under it before the tests start, else the header is one line.
        private const int OutputOpeningRows = 12;
        private const string OutputBorder = "38;5;68";

        private string _outputTitle;
        private readonly List<string> _output = new List<string>();
        // The line of progress at the bottom of the box, which each line of progress replaces.
        private string _outputStatus;
        private int _outputCount;
        private Stopwatch _outputClock;
        private MtOutputProgress _outputProgress;
        // How long the stage has run: it starts again when the stage changes.
        private Stopwatch _outputStageClock;
        private readonly List<string> _outputErrors = new List<string>();
        private int _outputErrorCount;
        // The lanes that the groups of the progress give (such as the pillars of an assessment): the dashboard
        // shows them in place of the products while the box has them.
        private List<Lane> _outputLanes;
        // How long each item took that finished, in the order they finished, and the slowest of them: the Pace
        // graph and the Slowest panel show them while the box is open. They are kept across the stages, so the
        // graph draws an assessment's data collection and then its tests.
        private readonly List<double> _outputDurations = new List<double>();
        private readonly List<Slow> _outputSlowest = new List<Slow>();
        private readonly HashSet<string> _outputFinished = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        /// <summary>Whether the output box is open.</summary>
        public bool HasOutput { get { lock (_gate) return _outputTitle != null; } }

        /// <summary>Opens the output box with this title, empty. A box that is open starts again.</summary>
        public void StartOutput(string title)
        {
            lock (_gate)
            {
                OpenOutput(title);
                Redraw();
            }
        }

        /// <summary>Adds lines to the output box, opening it when it is not open. Line breaks in the text start new lines.</summary>
        public void WriteOutput(string text)
        {
            WriteOutput(text, false);
        }

        /// <summary>
        /// Adds lines to the output box. With <paramref name="progress"/> the text is a status that changes (such
        /// as a count of tests done): one line, pinned at the bottom of the box under the lines that scroll, and
        /// replaced by the next line of progress. Empty progress text removes it.
        /// </summary>
        public void WriteOutput(string text, bool progress)
        {
            lock (_gate)
            {
                if (_outputTitle == null) OpenOutput(null);
                text = (text ?? string.Empty).Replace("\r\n", "\n");
                if (progress)
                {
                    string status = OutputText(text.Replace('\n', ' ').Replace('\r', ' ')).Trim();
                    _outputStatus = status.Length > 0 ? status : null;
                    Redraw();
                    return;
                }
                foreach (var part in text.Split('\n'))
                {
                    // A carriage return goes back to the start of the line: what comes after it is what a terminal shows.
                    int back = part.LastIndexOf('\r');
                    _output.Add(OutputText(back >= 0 ? part.Substring(back + 1) : part));
                    _outputCount++;
                }
                if (_output.Count > OutputKept) _output.RemoveRange(0, _output.Count - OutputKept);
                Redraw();
            }
        }

        /// <summary>
        /// Sets where the work in the output box is, shown as a header at the top of the box, opening the box
        /// when it is not open. Each call replaces the one before; null removes the header and the errors, and opens no box.
        /// </summary>
        public void SetOutputProgress(MtOutputProgress progress)
        {
            lock (_gate)
            {
                if (progress == null)
                {
                    // Clearing removes the progress and the errors, and opens no box.
                    if (_outputTitle == null) return;
                    _outputProgress = null;
                    _outputLanes = null;
                    ClearOutputTimes();
                    _outputStageClock = null;
                    _outputErrors.Clear();
                    _outputErrorCount = 0;
                    Redraw();
                    return;
                }
                if (_outputTitle == null) OpenOutput(null);
                var next = progress.Clean();
                if (next == null) _outputStageClock = null;
                else if (_outputProgress == null || _outputStageClock == null || next.StageNumber != _outputProgress.StageNumber || next.Stage != _outputProgress.Stage)
                {
                    _outputStageClock = Stopwatch.StartNew();
                }
                _outputProgress = next;
                _outputLanes = OutputLanes(next);
                AddOutputTimes(next);
                Redraw();
            }
        }

        /// <summary>Adds an error the work reported to the header of the output box, opening the box when it is not open.</summary>
        public void AddOutputError(string text)
        {
            lock (_gate)
            {
                if (_outputTitle == null) OpenOutput(null);
                text = OutputText((text ?? string.Empty).Replace('\r', ' ').Replace('\n', ' ')).Trim();
                if (text.Length == 0) return;
                _outputErrors.Add(text);
                _outputErrorCount++;
                if (_outputErrors.Count > OutputErrorsKept) _outputErrors.RemoveAt(0);
                Redraw();
            }
        }

        /// <summary>Closes the output box. Safe to call when it is not open.</summary>
        public void StopOutput()
        {
            lock (_gate)
            {
                if (_outputTitle == null) return;
                _outputTitle = null;
                _output.Clear();
                _outputStatus = null;
                _outputCount = 0;
                _outputClock = null;
                _outputProgress = null;
                _outputStageClock = null;
                _outputErrors.Clear();
                _outputErrorCount = 0;
                Redraw();
            }
        }

        private void OpenOutput(string title)
        {
            title = OutputText(title).Trim();
            _outputTitle = title.Length > 0 ? title : "Output";
            _output.Clear();
            _outputStatus = null;
            _outputCount = 0;
            _outputClock = Stopwatch.StartNew();
            _outputProgress = null;
            _outputLanes = null;
            ClearOutputTimes();
            _outputStageClock = null;
            _outputErrors.Clear();
            _outputErrorCount = 0;
        }

        private void ClearOutputTimes()
        {
            _outputDurations.Clear();
            _outputSlowest.Clear();
            _outputFinished.Clear();
        }

        /// <summary>Keeps the time of each item of the progress that finished and was not seen before.</summary>
        private void AddOutputTimes(MtOutputProgress p)
        {
            foreach (var item in p.Items)
            {
                if (item.IsRunning || item.Seconds < 0 || !_outputFinished.Add(p.StageNumber + "|" + item.Id + "|" + item.Title)) continue;
                _outputDurations.Add(item.Seconds);
                if (_outputSlowest.Count < SlowestKept || item.Seconds > _outputSlowest[_outputSlowest.Count - 1].Duration.TotalSeconds)
                {
                    _outputSlowest.Add(new Slow { Id = item.Id, Title = item.Title, Duration = TimeSpan.FromSeconds(item.Seconds) });
                    _outputSlowest.Sort((a, b) => b.Duration.CompareTo(a.Duration));
                    if (_outputSlowest.Count > SlowestKept) _outputSlowest.RemoveAt(SlowestKept);
                }
            }
        }

        /// <summary>Whether the Pace graph and the Slowest panel show the times of the work in the output box.</summary>
        private bool OutputTimed { get { return _outputTitle != null && _outputDurations.Count > 0; } }

        /// <summary>The times the Pace graph draws: those of the work in the output box while it has some, else the run's.</summary>
        private List<double> PaceDurations { get { return OutputTimed ? _outputDurations : _durations; } }

        /// <summary>The items the Slowest panel lists: the work's in the output box while it has some, else the run's tests.</summary>
        private List<Slow> SlowestShown { get { return OutputTimed ? _outputSlowest : _slowest; } }

        /// <summary>
        /// The results of the work in the output box, when its progress counts them (such as the tests of an
        /// assessment that runs in another process). While the box is open the Results panel, the result blocks
        /// and the Slowest panel show the work's own in place of Maester's.
        /// </summary>
        private MtOutputGroup OutputResults { get { return _outputTitle != null && _outputProgress != null ? _outputProgress.Results : null; } }

        /// <summary>The name of the work whose results are shown: the name of its results, else the title of the box.</summary>
        private string OutputResultsName
        {
            get
            {
                var r = OutputResults;
                return r != null && r.Name.Length > 0 ? r.Name : _outputTitle;
            }
        }

        /// <summary>The lanes to show: the groups of the work in the output box while it has them, else the products of the run.</summary>
        private List<Lane> Lanes { get { return _outputLanes ?? _lanes; } }

        /// <summary>The title of the box of lanes: what the groups of the work are called, else Products.</summary>
        private string LanesTitle
        {
            get
            {
                if (_outputLanes == null) return "Products";
                return _outputProgress != null && _outputProgress.GroupLabel.Length > 0 ? _outputProgress.GroupLabel : "Groups";
            }
        }

        private static List<Lane> OutputLanes(MtOutputProgress p)
        {
            if (p == null || p.Groups.Length == 0) return null;
            var lanes = new List<Lane>();
            foreach (var g in p.Groups)
            {
                lanes.Add(new Lane { Name = g.Name, Total = g.Total, Passed = g.Passed, Failed = g.Failed, Error = g.Error, Investigate = g.Investigate, Skipped = g.Skipped, Running = g.Running });
            }
            return lanes;
        }

        /// <summary>
        /// Before the tests start, the boxes of the work in the output box over it: its groups where the products
        /// are shown, and a block for each of its results, in the rows that <paramref name="rows"/> leaves over
        /// the box's own.
        /// </summary>
        private List<Line> BuildOutputView(int boxWidth, int rows, bool ansi)
        {
            var view = new List<Line>();
            var r = OutputResults;
            if (_outputLanes == null && r == null) return view;
            int inner = boxWidth - 4;
            int spare = rows - OutputTestRows;
            if (_outputLanes != null && spare >= 4)
            {
                var lanes = BuildLaneRows(inner, Math.Min(_outputLanes.Count, spare - 2), string.Empty, new List<Lane>(), ansi);
                var box = new PanelContent { Title = LanesTitle, Badge = N(_outputLanes.Count), Colour = ProductsBorder, TitleColour = ProductsBorder, Lines = lanes };
                view.AddRange(Indent(Box(box, boxWidth, ansi)));
                spare -= lanes.Count + 2;
            }
            if (r != null && spare >= 3)
            {
                var blocks = BuildResultsChart(inner, spare - 2, string.Empty, ansi);
                if (blocks.Count > 0) view.AddRange(Indent(Box(new PanelContent { Title = OutputResultsName, Badge = N(r.Done) + " of " + N(r.Total), Lines = blocks }, boxWidth, ansi)));
            }
            return view;
        }

        /// <summary>
        /// The header of the box in at most <paramref name="rows"/> rows: the stages as a track (done, the one
        /// running, those to come), a bar of the items of the stage done with the counts and the time left, the
        /// items running and the ones that finished last in the way the dashboard lists Maester's own tests, and
        /// the newest errors. When the log has lines it keeps four rows. Empty when there is no progress and no error.
        /// </summary>
        private List<Line> BuildOutputHeader(int inner, int rows, bool ansi)
        {
            var top = new List<Line>();
            var p = _outputProgress;
            string dot = Dot;
            if (p != null)
            {
                if (p.Stages.Length > 1) top.Add(BuildStageTrack(p, inner, ansi));
                else if (p.Stage.Length > 0 || p.StageNumber > 0)
                {
                    var b = new LineBuilder(ansi);
                    if (p.StageNumber > 0) b.Add(p.StageCount >= p.StageNumber ? "Stage " + p.StageNumber + " of " + p.StageCount : "Stage " + p.StageNumber, "2");
                    if (p.StageNumber > 0 && p.Stage.Length > 0) b.Add(dot, "2");
                    b.Add(p.Stage, "1");
                    top.Add(Truncate(b.Build(), inner, ansi));
                }
                var counts = new LineBuilder(ansi);
                // The name of the stage, when the track does not show it already (a stage can have steps of its own).
                bool named = p.StageNumber >= 1 && p.StageNumber <= p.Stages.Length && string.Equals(p.Stages[p.StageNumber - 1], p.Stage, StringComparison.OrdinalIgnoreCase);
                if (p.Stages.Length > 1 && p.Stage.Length > 0 && !named) counts.Add(p.Stage, "1").Add("  ");
                if (p.Total > 0)
                {
                    int done = Math.Min(p.Completed + p.Failed, p.Total);
                    AddBar(counts, done, p.Total, Math.Max(4, Math.Min(30, inner / 4)));
                    counts.Add(" " + N(done) + " / " + N(p.Total));
                    counts.Add(" " + (100L * done / p.Total).ToString(CultureInfo.InvariantCulture) + "%", "2");
                }
                else if (p.Completed > 0) counts.Add(N(p.Completed) + " done");
                if (p.Failed > 0) counts.Add(dot, "2").Add(N(p.Failed) + " failed", "31");
                if (p.Running > 0) counts.Add(dot, "2").Add(N(p.Running) + " running", "2");
                if (_outputStageClock != null && (p.Total > 0 || p.Stage.Length > 0))
                {
                    var elapsed = _outputStageClock.Elapsed;
                    counts.Add(dot, "2").Add(Short(elapsed), "2");
                    int finished = p.Completed + p.Failed;
                    if (p.Total > finished && finished > 0 && elapsed.TotalSeconds >= 15)
                    {
                        var left = TimeSpan.FromSeconds(elapsed.TotalSeconds / finished * (p.Total - finished));
                        counts.Add(dot, "2").Add("about " + Short(left) + " left", "2");
                    }
                }
                if (counts.Length > 0) top.Add(Truncate(counts.Build(), inner, ansi));
            }
            var errors = new List<Line>();
            for (int i = Math.Max(0, _outputErrors.Count - 2); i < _outputErrors.Count; i++)
            {
                errors.Add(Truncate(new LineBuilder(ansi).Add(Bad + " ", "31").Add(_outputErrors[i], "31").Build(), inner, ansi));
            }

            // The items have the rows the stages, the counts and the errors leave, and the log keeps four.
            var items = new List<Line>();
            if (p != null)
            {
                int room = rows - top.Count - errors.Count - (_output.Count > 0 ? 4 : 0);
                if (p.Items.Length > 0) items = BuildOutputItems(p.Items, inner, Math.Max(0, room), ansi);
                else
                {
                    if (p.Current.Length > 0) items.Add(Truncate(new LineBuilder(ansi).Add(Spinner() + " ", "36").Add(string.Join(", ", p.Current)).Build(), inner, ansi));
                    if (p.Status.Length > 0) items.Add(Truncate(new LineBuilder(ansi).Add(p.Status, "2").Build(), inner, ansi));
                    if (items.Count > Math.Max(0, room)) items.RemoveRange(Math.Max(0, room), items.Count - Math.Max(0, room));
                }
            }
            var lines = new List<Line>(top);
            lines.AddRange(items);
            lines.AddRange(errors);
            return lines;
        }

        /// <summary>
        /// The stages as the dashboard draws its phases: a mark and a name for each, joined by a line that is solid
        /// up to the stage running. Too long for the box, the stages other than the one running show their number only.
        /// </summary>
        private Line BuildStageTrack(MtOutputProgress p, int inner, bool ansi)
        {
            int current = p.StageNumber;
            for (int form = 0; form < 2; form++)
            {
                var b = new LineBuilder(ansi);
                for (int i = 0; i < p.Stages.Length; i++)
                {
                    int number = i + 1;
                    var state = number < current ? SegmentState.Done : number == current ? SegmentState.Active : SegmentState.Waiting;
                    string name = form == 0 || state == SegmentState.Active ? number + " " + p.Stages[i] : number.ToString(CultureInfo.InvariantCulture);
                    if (i > 0)
                    {
                        b.Add(" ");
                        if (state == SegmentState.Waiting) b.Add(new string(Unicode ? '┄' : '.', 2), WaitingCell);
                        else b.Add(new string(Unicode ? '━' : '=', 2), "32");
                        b.Add(" ");
                    }
                    b.AddLine(StopLabel(name, state, ansi));
                }
                if (b.Length <= inner || form == 1) return Truncate(b.Build(), inner, ansi);
            }
            return Blank();
        }

        /// <summary>
        /// The items in at most <paramref name="rows"/> rows: the ones running first, oldest first, as the
        /// dashboard shows the tests that run, then the ones that finished, newest first, as it shows the tests
        /// that ran, each with its time at the right.
        /// </summary>
        private List<Line> BuildOutputItems(MtOutputItem[] items, int inner, int rows, bool ansi)
        {
            var lines = new List<Line>();
            var running = new List<MtOutputItem>();
            var finished = new List<MtOutputItem>();
            foreach (var item in items) (item.IsRunning ? running : finished).Add(item);
            int hidden = 0;
            // Room for a line that counts the items running that do not fit.
            int runningRows = running.Count > rows ? Math.Max(0, rows - 1) : running.Count;
            hidden = running.Count - runningRows;
            for (int i = 0; i < runningRows; i++)
            {
                var item = running[i];
                var b = new LineBuilder(ansi).Add(Spinner() + " ", "36");
                AddItemName(b, item, "1", null);
                if (item.Detail.Length > 0) b.Add("  " + item.Detail, "2");
                lines.Add(ItemLine(b, item.Seconds, inner, ansi));
            }
            if (hidden > 0) lines.Add(new LineBuilder(ansi).Add("  " + N(hidden) + " more running", "2").Build());
            for (int i = finished.Count - 1; i >= 0 && lines.Count < rows; i--)
            {
                var item = finished[i];
                string mark;
                string colour;
                switch (item.Status)
                {
                    case "Failed": mark = Bad; colour = "31"; break;
                    case "TimedOut": mark = "!"; colour = "33"; break;
                    case "Skipped": mark = Dash; colour = "2"; break;
                    default: mark = Ok; colour = "32"; break;
                }
                var b = new LineBuilder(ansi).Add(mark + " ", colour);
                AddItemName(b, item, "2", "2");
                if (item.Status == "Failed" || item.Status == "TimedOut") { if (item.Detail.Length > 0) b.Add("  " + item.Detail, colour); }
                lines.Add(ItemLine(b, item.Seconds, inner, ansi));
            }
            return lines;
        }

        private void AddItemName(LineBuilder b, MtOutputItem item, string idColour, string titleColour)
        {
            if (item.Title.Length == 0) b.Add(item.Id, idColour == "1" ? null : idColour);
            else b.Add(FitId(item.Id) + " ", idColour).Add(item.Title, titleColour);
        }

        private Line ItemLine(LineBuilder b, double seconds, int inner, bool ansi)
        {
            if (seconds < 0) return Truncate(b.Build(), inner, ansi);
            string time = Short(TimeSpan.FromSeconds(seconds)).PadLeft(7);
            var cut = Truncate(b.Build(), inner - time.Length - 1, ansi);
            string gap = new string(' ', Math.Max(1, inner - time.Length - cut.Plain.Length));
            return new Line { Text = cut.Text + gap + (ansi ? Esc + "2m" + time + Esc + "0m" : time), Plain = cut.Plain + gap + time };
        }

        /// <summary>
        /// The box, <paramref name="height"/> rows with its border: the newest lines that fit, wrapped to its
        /// width, so the box scrolls as lines come in, and the line of progress under them. Empty when the box is
        /// not open or has no room.
        /// </summary>
        private List<Line> BuildOutputBox(int boxWidth, int height, bool ansi)
        {
            if (_outputTitle == null || height < 3 || boxWidth < 12) return new List<Line>();
            int inner = boxWidth - 4;
            int inside = height - 2;
            // The line of progress has the last row, under a dashed line when there are rows for one.
            int pinned = _outputStatus == null ? 0 : inside >= 4 ? 2 : inside >= 2 ? 1 : 0;
            inside -= pinned;
            // The rows above the progress line, which the header, the log and blank rows fill.
            int body = inside;
            // The header has the top rows; the log has the rows under it, after a dashed line when there is room.
            var head = BuildOutputHeader(inner, inside, ansi);
            if (head.Count > inside) head.RemoveRange(inside, head.Count - inside);
            inside -= head.Count;
            bool ruled = head.Count > 0 && inside >= 2;
            if (ruled) inside--;
            var shown = new List<string>();
            for (int i = _output.Count - 1; i >= 0 && shown.Count < inside; i--)
            {
                var wrapped = WrapOutput(_output[i], inner);
                for (int j = wrapped.Count - 1; j >= 0 && shown.Count < inside; j--) shown.Add(wrapped[j]);
            }
            shown.Reverse();

            var lines = new List<Line>(head);
            if (ruled) lines.Add(new Line { Text = string.Empty, Plain = string.Empty, Rule = "Log", Dashed = true });
            if (shown.Count == 0 && (head.Count == 0 || ruled)) lines.Add(new LineBuilder(ansi).Add(Spinner() + " Waiting for output" + Ellipsis(), "2").Build());
            foreach (var s in shown) lines.Add(new Line { Text = s, Plain = s });
            while (lines.Count < body) lines.Add(Blank());
            if (pinned == 2) lines.Add(new Line { Text = string.Empty, Plain = string.Empty, Rule = "Progress", Dashed = true });
            if (pinned > 0) lines.Add(new LineBuilder(ansi).Add(Spinner() + " ", "36").Add(_outputStatus).Build());

            string badge = _outputClock != null ? Short(_outputClock.Elapsed) : null;
            if (_outputCount > 0) badge = (badge != null ? badge + " · " : string.Empty) + Count(_outputCount, "line");
            if (_outputErrorCount > 0) badge = (badge != null ? badge + " · " : string.Empty) + Count(_outputErrorCount, "error");
            var box = new PanelContent { Title = _outputTitle, Badge = badge, Colour = OutputBorder, TitleColour = OutputBorder, Lines = lines };
            return Indent(Box(box, boxWidth, ansi));
        }

        /// <summary>A line cut into pieces of at most <paramref name="width"/> characters, at a space where there is one.</summary>
        private static List<string> WrapOutput(string s, int width)
        {
            var pieces = new List<string>();
            width = Math.Max(1, width);
            while (s.Length > width)
            {
                int cut = s.LastIndexOf(' ', width);
                if (cut < width / 2) cut = width;
                pieces.Add(s.Substring(0, cut).TrimEnd());
                s = s.Substring(cut).TrimStart();
            }
            pieces.Add(s);
            return pieces;
        }

        /// <summary>
        /// A line from another program made safe for the box: escape sequences are removed and tabs become
        /// spaces, other control characters and characters that hide or reorder text are dropped, and so are
        /// emoji, whose width terminals do not agree on (a wrong guess pushes the border out of line).
        /// </summary>
        public static string OutputText(string s)
        {
            if (string.IsNullOrEmpty(s)) return string.Empty;
            s = StripAnsi(s);
            var sb = new StringBuilder(s.Length);
            bool dropped = false;
            foreach (char c in s)
            {
                if (c == '\t')
                {
                    sb.Append(' ', 4 - sb.Length % 4);
                    continue;
                }
                if (char.IsControl(c) || c == '\u2028' || c == '\u2029' || IsHiddenFormat(c) ||
                    char.IsSurrogate(c) || c == '\uFE0F' || c == '\uFE0E' || c == '\u200D' || IsWideSymbol(c))
                {
                    dropped = true;
                    continue;
                }
                // The space after an emoji that starts the line, or that follows a space, goes with it.
                if (c == ' ' && dropped && (sb.Length == 0 || sb[sb.Length - 1] == ' '))
                {
                    dropped = false;
                    continue;
                }
                dropped = false;
                sb.Append(c);
            }
            return sb.ToString().TrimEnd();
        }

        /// <summary>The symbols of the Basic Multilingual Plane that terminals draw as emoji, two columns wide.</summary>
        private static bool IsWideSymbol(char c)
        {
            if (c < '\u231A' || c > '\u2B55') return false;
            return c == '\u231A' || c == '\u231B' || (c >= '\u23E9' && c <= '\u23EC') || c == '\u23F0' || c == '\u23F3' ||
                c == '\u25FD' || c == '\u25FE' || c == '\u2614' || c == '\u2615' || (c >= '\u2648' && c <= '\u2653') ||
                c == '\u267F' || c == '\u2693' || c == '\u26A1' || c == '\u26AA' || c == '\u26AB' || c == '\u26BD' ||
                c == '\u26BE' || c == '\u26C4' || c == '\u26C5' || c == '\u26CE' || c == '\u26D4' || c == '\u26EA' ||
                c == '\u26F2' || c == '\u26F3' || c == '\u26F5' || c == '\u26FA' || c == '\u26FD' || c == '\u2705' ||
                c == '\u270A' || c == '\u270B' || c == '\u2728' || c == '\u274C' || c == '\u274E' ||
                (c >= '\u2753' && c <= '\u2755') || c == '\u2757' || (c >= '\u2795' && c <= '\u2797') || c == '\u27B0' ||
                c == '\u27BF' || c == '\u2B1B' || c == '\u2B1C' || c == '\u2B50' || c == '\u2B55';
        }
    }

    /// <summary>
    /// Where the work in the output box is: what Write-MtTestProgress hands the renderer. Every part is optional.
    /// </summary>
    public sealed class MtOutputProgress
    {
        /// <summary>The name of the stage the work is in, such as "Exporting tenant data".</summary>
        public string Stage { get; set; }
        /// <summary>The number of the stage, from 1, and how many stages there are.</summary>
        public int StageNumber { get; set; }
        public int StageCount { get; set; }
        /// <summary>The items of the stage done, failed and running, of how many.</summary>
        public int Completed { get; set; }
        public int Total { get; set; }
        public int Failed { get; set; }
        public int Running { get; set; }
        /// <summary>What the work is on now, such as the names of the items running.</summary>
        public string[] Current { get; set; }
        /// <summary>A line of status that fits no other part.</summary>
        public string Status { get; set; }
        /// <summary>The names of all the stages, in order: the header draws them as a track, StageNumber the one running.</summary>
        public string[] Stages { get; set; }
        /// <summary>The items running and the ones that finished last, each with its status and time.</summary>
        public MtOutputItem[] Items { get; set; }
        /// <summary>The results of the work so far, such as the tests of an assessment that passed and failed.</summary>
        public MtOutputGroup Results { get; set; }
        /// <summary>The results by group, such as the pillars of an assessment, and what the groups are called.</summary>
        public MtOutputGroup[] Groups { get; set; }
        public string GroupLabel { get; set; }

        private static string Text(string s)
        {
            return MtConsoleRenderer.OutputText((s ?? string.Empty).Replace('\r', ' ').Replace('\n', ' ')).Trim();
        }

        /// <summary>A copy made safe to draw: text from another program cleaned, no negative counts.</summary>
        public MtOutputProgress Clean()
        {
            var current = new List<string>();
            if (Current != null)
            {
                foreach (var c in Current)
                {
                    string t = Text(c);
                    if (t.Length > 0) current.Add(t);
                }
            }
            var stages = new List<string>();
            if (Stages != null) foreach (var st in Stages) stages.Add(Text(st));
            var items = new List<MtOutputItem>();
            if (Items != null)
            {
                foreach (var item in Items)
                {
                    if (item == null) continue;
                    var clean = new MtOutputItem { Id = Text(item.Id), Title = Text(item.Title), Detail = Text(item.Detail), Status = Text(item.Status), Seconds = item.Seconds };
                    if (clean.Id.Length == 0 && clean.Title.Length == 0) continue;
                    if (clean.Status.Length == 0) clean.Status = "Running";
                    // A time TimeSpan cannot hold is unknown.
                    if (double.IsNaN(clean.Seconds) || double.IsInfinity(clean.Seconds) || clean.Seconds >= TimeSpan.MaxValue.TotalSeconds) clean.Seconds = -1;
                    items.Add(clean);
                }
            }
            var groups = new List<MtOutputGroup>();
            if (Groups != null)
            {
                foreach (var g in Groups)
                {
                    var clean = g == null ? null : g.Clean();
                    if (clean != null && clean.Name.Length > 0) groups.Add(clean);
                }
            }
            return new MtOutputProgress
            {
                Stage = Text(Stage),
                StageNumber = Math.Max(0, StageNumber),
                StageCount = Math.Max(0, StageCount),
                Completed = Math.Max(0, Completed),
                Total = Math.Max(0, Total),
                Failed = Math.Max(0, Failed),
                Running = Math.Max(0, Running),
                Current = current.ToArray(),
                Status = Text(Status),
                Stages = stages.ToArray(),
                Items = items.ToArray(),
                Results = Results == null ? null : Results.Clean(),
                Groups = groups.ToArray(),
                GroupLabel = Text(GroupLabel),
            };
        }
    }

    /// <summary>An item of the work in the output box, such as an export or a test of the tool, with its status and time.</summary>
    public sealed class MtOutputItem
    {
        /// <summary>What names the item, such as a test ID, and its title.</summary>
        public string Id { get; set; }
        public string Title { get; set; }
        /// <summary>What the item is doing while it runs, or why it failed.</summary>
        public string Detail { get; set; }
        /// <summary>Running (the default), Passed, Failed, TimedOut or Skipped.</summary>
        public string Status { get; set; }
        /// <summary>How long it has run, or ran; negative when not known.</summary>
        public double Seconds { get; set; } = -1;

        internal bool IsRunning { get { return string.Equals(Status, "Running", StringComparison.OrdinalIgnoreCase) || string.Equals(Status, "Waiting", StringComparison.OrdinalIgnoreCase); } }
    }

    /// <summary>
    /// Results of the work in the output box, all of it or one group of it (such as a pillar of an assessment):
    /// how many items it has and how many of them passed, failed and so on.
    /// </summary>
    public sealed class MtOutputGroup
    {
        /// <summary>The name of the group, or of the work.</summary>
        public string Name { get; set; }
        /// <summary>The items, finished or not. A total smaller than the items counted is raised to it.</summary>
        public int Total { get; set; }
        public int Passed { get; set; }
        public int Failed { get; set; }
        public int Error { get; set; }
        public int Investigate { get; set; }
        public int Skipped { get; set; }
        /// <summary>The items running now.</summary>
        public int Running { get; set; }

        /// <summary>The items that have a result.</summary>
        public int Done { get { return Passed + Failed + Error + Investigate + Skipped; } }

        /// <summary>A copy made safe to draw: the name cleaned, no negative counts, a total that holds the counts.</summary>
        public MtOutputGroup Clean()
        {
            var c = new MtOutputGroup
            {
                Name = MtConsoleRenderer.OutputText((Name ?? string.Empty).Replace('\r', ' ').Replace('\n', ' ')).Trim(),
                Passed = Math.Max(0, Passed),
                Failed = Math.Max(0, Failed),
                Error = Math.Max(0, Error),
                Investigate = Math.Max(0, Investigate),
                Skipped = Math.Max(0, Skipped),
                Running = Math.Max(0, Running),
            };
            c.Total = Math.Max(Math.Max(0, Total), c.Done);
            return c;
        }
    }
}
