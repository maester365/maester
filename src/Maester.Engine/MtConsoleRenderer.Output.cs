using System;
using System.Collections.Generic;
using System.Diagnostics;
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
        private int OutputTestRows { get { return _outputProgress != null || _outputErrors.Count > 0 ? 14 : 10; } }
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
        private readonly List<string> _outputErrors = new List<string>();
        private int _outputErrorCount;

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
        /// when it is not open. Each call replaces the one before; null removes the header.
        /// </summary>
        public void SetOutputProgress(MtOutputProgress progress)
        {
            lock (_gate)
            {
                if (_outputTitle == null) OpenOutput(null);
                _outputProgress = progress == null ? null : progress.Clean();
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
            _outputErrors.Clear();
            _outputErrorCount = 0;
        }

        /// <summary>
        /// The header of the box: the stage, a bar of the items done with the counts, what the work is on now, a
        /// line of status and the newest errors. Empty when there is no progress and no error.
        /// </summary>
        private List<Line> BuildOutputHeader(int inner, bool ansi)
        {
            var lines = new List<Line>();
            var p = _outputProgress;
            string dot = Unicode ? " · " : " - ";
            if (p != null)
            {
                if (p.Stage.Length > 0 || p.StageNumber > 0)
                {
                    var b = new LineBuilder(ansi);
                    if (p.StageNumber > 0) b.Add(p.StageCount >= p.StageNumber ? "Stage " + p.StageNumber + " of " + p.StageCount : "Stage " + p.StageNumber, "2");
                    if (p.StageNumber > 0 && p.Stage.Length > 0) b.Add(dot, "2");
                    b.Add(p.Stage, "1");
                    lines.Add(Truncate(b.Build(), inner, ansi));
                }
                if (p.Total > 0 || p.Completed > 0 || p.Failed > 0 || p.Running > 0)
                {
                    var b = new LineBuilder(ansi);
                    if (p.Total > 0)
                    {
                        AddBar(b, Math.Min(p.Completed, p.Total), p.Total, Math.Max(4, Math.Min(30, inner / 3)));
                        b.Add(" " + N(p.Completed) + " / " + N(p.Total));
                    }
                    else b.Add(N(p.Completed) + " done");
                    if (p.Failed > 0) b.Add(dot, "2").Add(N(p.Failed) + " failed", "31");
                    if (p.Running > 0) b.Add(dot, "2").Add(N(p.Running) + " running", "2");
                    lines.Add(Truncate(b.Build(), inner, ansi));
                }
                if (p.Current.Length > 0)
                {
                    var b = new LineBuilder(ansi).Add(Spinner() + " ", "36").Add(string.Join(", ", p.Current));
                    lines.Add(Truncate(b.Build(), inner, ansi));
                }
                if (p.Status.Length > 0) lines.Add(Truncate(new LineBuilder(ansi).Add(p.Status, "2").Build(), inner, ansi));
            }
            for (int i = Math.Max(0, _outputErrors.Count - 2); i < _outputErrors.Count; i++)
            {
                lines.Add(Truncate(new LineBuilder(ansi).Add(Bad + " ", "31").Add(_outputErrors[i], "31").Build(), inner, ansi));
            }
            return lines;
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
            // The header has the top rows; the log has the rows under it, after a dashed line when there is room.
            var head = BuildOutputHeader(inner, ansi);
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
            while (lines.Count < inside) lines.Add(Blank());
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

        /// <summary>A copy made safe to draw: text from another program cleaned, no negative counts.</summary>
        public MtOutputProgress Clean()
        {
            var current = new List<string>();
            if (Current != null)
            {
                foreach (var c in Current)
                {
                    string t = MtConsoleRenderer.OutputText((c ?? string.Empty).Replace('\r', ' ').Replace('\n', ' ')).Trim();
                    if (t.Length > 0) current.Add(t);
                }
            }
            return new MtOutputProgress
            {
                Stage = MtConsoleRenderer.OutputText((Stage ?? string.Empty).Replace('\r', ' ').Replace('\n', ' ')).Trim(),
                StageNumber = Math.Max(0, StageNumber),
                StageCount = Math.Max(0, StageCount),
                Completed = Math.Max(0, Completed),
                Total = Math.Max(0, Total),
                Failed = Math.Max(0, Failed),
                Running = Math.Max(0, Running),
                Current = current.ToArray(),
                Status = MtConsoleRenderer.OutputText((Status ?? string.Empty).Replace('\r', ' ').Replace('\n', ' ')).Trim(),
            };
        }
    }
}
