using System;
using System.Collections.Generic;
using System.Text;

namespace Maester.Engine
{
    /// <summary>
    /// The top of the screen of the game. On a screen with the room it is a band of five rows: the name
    /// in letters of blocks, in the colours of the wordmark from Maester red to amber; the hearts as
    /// sprites, full and empty; the score in large digits, with the streak and the best score; and at the
    /// right the run itself. On a smaller screen, and on one without Unicode, it is one line.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const int GameBandRows = 5;
        private const int GameBandWidth = 120;
        private const int GameBandHeight = 40;
        private const string GameHeartFull = "1;38;5;196";
        private const string GameHeartEmpty = "38;5;240";

        // The letters of the name, five rows of blocks each.
        private static readonly string[] BandM = { "#   #", "## ##", "# # #", "#   #", "#   #" };
        private static readonly string[] BandA = { " # ", "# #", "###", "# #", "# #" };
        private static readonly string[] BandE = { "###", "#  ", "## ", "#  ", "###" };
        private static readonly string[] BandS = { "###", "#  ", "###", "  #", "###" };
        private static readonly string[] BandT = { "###", " # ", " # ", " # ", " # " };
        private static readonly string[] BandR = { "###", "# #", "## ", "# #", "# #" };
        private static readonly string[] BandU = { "# #", "# #", "# #", "# #", "###" };
        private static readonly string[] BandN = { "#  #", "## #", "# ##", "#  #", "#  #" };
        private static readonly string[] BandGap = { "  ", "  ", "  ", "  ", "  " };
        private static readonly string[] BandName = BandWord(BandM, BandA, BandE, BandS, BandT, BandE, BandR, BandGap, BandR, BandU, BandN);

        // The digits of the score: three dots wide and five high, and two of those to a row. And the
        // comma between the thousands.
        private static readonly string[][] BandDigits =
        {
            new[] { "###", "# #", "# #", "# #", "###" }, new[] { " # ", "## ", " # ", " # ", "###" }, new[] { "###", "  #", "###", "#  ", "###" },
            new[] { "###", "  #", "###", "  #", "###" }, new[] { "# #", "# #", "###", "  #", "  #" }, new[] { "###", "#  ", "###", "  #", "###" },
            new[] { "###", "#  ", "###", "# #", "###" }, new[] { "###", "  #", "  #", "  #", "  #" }, new[] { "###", "# #", "###", "# #", "###" },
            new[] { "###", "# #", "###", "  #", "###" }
        };
        private static readonly string[] BandComma = { "  ", "  ", "  ", " #", "# " };

        // A heart that is left, and one that is gone.
        private static readonly string[] BandHeart = { "▟▙▟▙", "▝██▘" };
        private static readonly string[] BandNoHeart = { "╭╮╭╮", " ╰╯ " };

        private Line[] _bandName;
        private bool _bandNameAnsi;
        private bool _bandNameTrue;

        // The name in two rows, for the frame after the run.
        private static readonly string[] GameSmallName =
        {
            "█▀▄▀█ ▄▀█ █▀▀ █▀ ▀█▀ █▀▀ █▀█   █▀█ █ █ █▄ █",
            "█ ▀ █ █▀█ ██▄ ▄█  █  ██▄ █▀▄   █▀▄ █▄█ █ ▀█"
        };

        /// <summary>The rows of letters side by side, a column between two of them.</summary>
        private static string[] BandWord(params string[][] letters)
        {
            var rows = new string[GameBandRows];
            for (int r = 0; r < rows.Length; r++)
            {
                var sb = new StringBuilder();
                for (int i = 0; i < letters.Length; i++)
                {
                    if (i > 0) sb.Append(' ');
                    sb.Append(letters[i][r]);
                }
                rows[r] = sb.ToString();
            }
            return rows;
        }

        /// <summary>The rows of the top of the screen of the game: five where the band has room, and one otherwise.</summary>
        private int GameHudRows(int width, int height)
        {
            return Unicode && width >= GameBandWidth && height >= GameBandHeight ? GameBandRows : 1;
        }

        /// <summary>The rows of the screen that are not the playfield: the top, the progress bar, the ticker and the keys.</summary>
        private int GameFrameRows(int width, int height)
        {
            return GameHudRows(width, height) + 3;
        }

        /// <summary>
        /// The colour of a column of the name: the gradient of the wordmark, Maester red to amber. In
        /// 24 bits where the terminal has them, and otherwise the nearest of the 216 colours of the cube.
        /// </summary>
        private string NameColour(int index, int count)
        {
            double t = count > 1 ? (double)index / (count - 1) * (BarStops.Length - 1) : 0;
            int segment = Math.Min((int)t, BarStops.Length - 2);
            var rgb = new int[3];
            for (int i = 0; i < 3; i++) rgb[i] = (int)(BarStops[segment][i] + (BarStops[segment + 1][i] - BarStops[segment][i]) * (t - segment));
            if (TrueColor) return "1;38;2;" + N(rgb[0]) + ";" + N(rgb[1]) + ";" + N(rgb[2]);
            int cube = 16;
            int[] weight = { 36, 6, 1 };
            for (int i = 0; i < 3; i++) cube += weight[i] * (int)Math.Round(rgb[i] / 255.0 * 5);
            return "1;38;5;" + N(cube);
        }

        /// <summary>
        /// The name of the game in two rows of half blocks, for the frame after the run: in the colours
        /// of the wordmark when <paramref name="colour"/> is set. Every row is as wide as the other.
        /// </summary>
        public string[] GetGameTitle(bool colour)
        {
            var rows = new string[GameSmallName.Length];
            for (int r = 0; r < rows.Length; r++)
            {
                var strip = new Strip(colour);
                string row = GameSmallName[r];
                for (int i = 0; i < row.Length; i++) strip.Add(row[i], row[i] == ' ' ? null : NameColour(i, row.Length));
                rows[r] = strip.Build().Text;
            }
            return rows;
        }

        /// <summary>The columns of the name that GetGameTitle gives.</summary>
        public int GameTitleWidth { get { return GameSmallName[0].Length; } }

        /// <summary>A row that is put together from pieces at their columns, each in its colours.</summary>
        private sealed class Strip
        {
            private readonly StringBuilder _text = new StringBuilder();
            private readonly StringBuilder _plain = new StringBuilder();
            private readonly bool _ansi;
            private string _pen;

            public Strip(bool ansi)
            {
                _ansi = ansi;
            }

            public int Length { get { return _plain.Length; } }

            /// <summary>Spaces up to a column. What is there already stays: a piece that would start in it starts after it.</summary>
            public Strip To(int column)
            {
                if (column <= _plain.Length) return this;
                Pen(null);
                int spaces = column - _plain.Length;
                _text.Append(' ', spaces);
                _plain.Append(' ', spaces);
                return this;
            }

            public Strip Add(string text, string sgr)
            {
                if (string.IsNullOrEmpty(text)) return this;
                Pen(sgr);
                _text.Append(text);
                _plain.Append(text);
                return this;
            }

            /// <summary>A piece that is written already, colours and all, and the columns it takes.</summary>
            public Strip AddWritten(string text, string plain)
            {
                Pen(null);
                _text.Append(text);
                _plain.Append(plain);
                return this;
            }

            public Strip Add(char c, string sgr)
            {
                Pen(c == ' ' ? _pen : sgr);
                _text.Append(c);
                _plain.Append(c);
                return this;
            }

            private void Pen(string sgr)
            {
                if (!_ansi || string.Equals(sgr, _pen, StringComparison.Ordinal)) return;
                _text.Append(Esc).Append('0');
                if (sgr != null) _text.Append(';').Append(sgr);
                _text.Append('m');
                _pen = sgr;
            }

            public Line Build()
            {
                Pen(null);
                return new Line { Text = _text.ToString(), Plain = _plain.ToString() };
            }
        }

        /// <summary>
        /// The band: its five rows. The name at the left; then the hearts, with the streak under them;
        /// the score in large digits, under the word and over the best score so far; and at the right
        /// the run, in two rows. What is between them is shared out, so that the band fills the width.
        /// </summary>
        private List<Line> GameBand(int max, bool ansi)
        {
            int done = FinishedCount();
            int percent = _total > 0 ? (int)Math.Min(100L, 100L * done / _total) : 0;
            string score = GameNumber(_game.Score);
            // The digits of 10,000 and its comma: the score has that much room, whatever it is.
            const int scoreWidth = 5 * 4 + 3 - 1;
            const int heartsWidth = Runner.Hearts * 4 + (Runner.Hearts - 1) * 2;
            int nameWidth = BandName[0].Length;
            // The run has thirty columns at the right, or what is left after three gaps of three: the
            // gaps do not change from frame to frame, so that nothing in the band moves.
            int reserve = Math.Min(30, max - 1 - nameWidth - heartsWidth - scoreWidth - 9);
            string[] runs =
            {
                "run " + ProgressText(done, CurrentPhaseClock(), false),
                "run " + N(done) + "/" + N(_total) + "  " + N(percent) + "%",
                N(done) + "/" + N(_total)
            };
            string counts = Ok + " " + N(_passed) + "  " + Bad + " " + N(_failed) + "  ! " + N(_error);
            string run = runs[runs.Length - 1];
            for (int i = runs.Length - 1; i >= 0; i--)
            {
                if (runs[i].Length <= reserve) run = runs[i];
            }
            int gap = Math.Max(3, (max - 1 - nameWidth - heartsWidth - scoreWidth - reserve) / 3);
            int hearts = 1 + nameWidth + gap;
            int digits = hearts + heartsWidth + gap;

            // The name is the same in every frame: it is written once.
            if (_bandName == null || _bandNameAnsi != ansi || _bandNameTrue != TrueColor)
            {
                _bandName = new Line[GameBandRows];
                for (int r = 0; r < GameBandRows; r++)
                {
                    var name = new Strip(ansi);
                    string letters = BandName[r];
                    for (int i = 0; i < letters.Length; i++) name.Add(letters[i] == ' ' ? ' ' : '█', NameColour(i, letters.Length));
                    _bandName[r] = name.Build();
                }
                _bandNameAnsi = ansi;
                _bandNameTrue = TrueColor;
            }

            var rows = new List<Line>(GameBandRows);
            for (int r = 0; r < GameBandRows; r++)
            {
                var strip = new Strip(ansi);
                strip.To(1);
                strip.AddWritten(_bandName[r].Text, _bandName[r].Plain);

                // The hearts, in the second and the third row, and under them the streak.
                strip.To(hearts);
                if (r == 1 || r == 2)
                {
                    for (int h = 0; h < Runner.Hearts; h++)
                    {
                        strip.To(hearts + h * 6);
                        bool left = h < _game.Lives;
                        strip.Add((left ? BandHeart : BandNoHeart)[r - 1], left ? GameHeartFull : GameHeartEmpty);
                    }
                }
                else if (r == 4)
                {
                    strip.Add("STREAK ", "2").Add(N(_game.Streak), _game.Streak > 0 ? "1;32" : "2");
                }

                // The score: the word, the digits in three rows, and the best score so far.
                strip.To(digits);
                if (r == 0)
                {
                    strip.Add("SCORE", "2");
                }
                else if (r <= 3)
                {
                    int at = digits;
                    foreach (char c in score)
                    {
                        strip.To(at);
                        string[] dots = c == ',' ? BandComma : BandDigits[c - '0'];
                        for (int x = 0; x < dots[0].Length; x++)
                        {
                            bool top = dots[2 * (r - 1)][x] == '#';
                            bool bottom = 2 * (r - 1) + 1 < dots.Length && dots[2 * (r - 1) + 1][x] == '#';
                            strip.Add(top && bottom ? '█' : (top ? '▀' : (bottom ? '▄' : ' ')), "1");
                        }
                        at += dots[0].Length + 1;
                    }
                }
                else if (_gameBest > 0)
                {
                    strip.Add("BEST " + GameNumber(_gameBest), "2");
                }
                else
                {
                    strip.Add("of " + GameNumber(GameFullScore), "2");
                }

                // The run: how far it is, and under that what it found.
                if (r == 1)
                {
                    strip.To(max - run.Length).Add(run, "1");
                }
                else if (r == 2)
                {
                    strip.To(max - counts.Length);
                    strip.Add(Ok + " " + N(_passed), "32").Add("  ", null).Add(Bad + " " + N(_failed), _failed > 0 ? "31" : "2").Add("  ", null).Add("! " + N(_error), _error > 0 ? "33" : "2");
                }
                rows.Add(Truncate(strip.Build(), max, ansi));
            }
            return rows;
        }
    }
}
