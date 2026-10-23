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
    /// pinned at the bottom of the box, StopOutput closes it. Before the tests start (a family's instance source runs then) the box
    /// takes the rows under the phases; while tests run it sits between the result blocks and the running tests.
    /// Only the dashboard draws it: in the compact layout the caller writes the lines to the scrollback.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        // The lines kept for the box: more than any console has rows for.
        private const int OutputKept = 500;
        // The rows of the box with its border: at least three lines in it, and while tests run ten rows.
        private const int OutputLeastRows = 5;
        private const int OutputTestRows = 10;
        // The rows the banner leaves the box under it before the tests start, else the header is one line.
        private const int OutputOpeningRows = 12;
        private const string OutputBorder = "38;5;68";

        private string _outputTitle;
        private readonly List<string> _output = new List<string>();
        // The line of progress at the bottom of the box, which each line of progress replaces.
        private string _outputStatus;
        private int _outputCount;
        private Stopwatch _outputClock;

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
            var shown = new List<string>();
            for (int i = _output.Count - 1; i >= 0 && shown.Count < inside; i--)
            {
                var wrapped = WrapOutput(_output[i], inner);
                for (int j = wrapped.Count - 1; j >= 0 && shown.Count < inside; j--) shown.Add(wrapped[j]);
            }
            shown.Reverse();

            var lines = new List<Line>();
            if (shown.Count == 0) lines.Add(new LineBuilder(ansi).Add(Spinner() + " Waiting for output" + Ellipsis(), "2").Build());
            foreach (var s in shown) lines.Add(new Line { Text = s, Plain = s });
            while (lines.Count < inside) lines.Add(Blank());
            if (pinned == 2) lines.Add(new Line { Text = string.Empty, Plain = string.Empty, Rule = "Progress", Dashed = true });
            if (pinned > 0) lines.Add(new LineBuilder(ansi).Add(Spinner() + " ", "36").Add(_outputStatus).Build());

            string badge = _outputClock != null ? Short(_outputClock.Elapsed) : null;
            if (_outputCount > 0) badge = (badge != null ? badge + " · " : string.Empty) + Count(_outputCount, "line");
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
}
