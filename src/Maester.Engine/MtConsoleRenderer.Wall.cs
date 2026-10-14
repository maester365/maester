using System;
using System.Collections.Generic;
using System.Text;

namespace Maester.Engine
{
    /// <summary>
    /// How the game comes on screen the first time in a run: the dashboard is a wall that is broken
    /// through. Cracks spread from a point for a moment, then a ragged hole grows from that point until
    /// the dashboard is gone, and the game is what shows through the hole all the while. After that the
    /// card of the help is on it, and the game waits for a key to start.
    ///
    /// The wall is the frame of the dashboard that was on screen, cell by cell with its colours and
    /// without its hyperlinks. A frame of the breaking is put together from it and from the frame of the
    /// game: a cell shows the game once the hole has reached it. Nothing here keeps a state between
    /// frames but the time, and what looks like chance comes from the seed of the wall: the same seed
    /// breaks the same wall the same way.
    ///
    /// The game does not move while the wall breaks, and any key ends the breaking at once. Whatever goes
    /// wrong ends it as well: the game is shown as it is without it.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const double WallSeconds = 1.3;
        private const double WallCrackSeconds = 0.35;
        private const double WallRim = 2.4;
        private const int WallCracks = 7;
        private const int WallDebris = 18;
        private const string WallRubble = "38;5;245";
        private const string WallCrackColour = "1;97";
        private static readonly string[] BossLines = { "DC01 DEcommissioned. AD is no more." };

        /// <summary>The cells of a frame: a character each, and the colour sequence it is written with.</summary>
        private sealed class WallCells
        {
            public int Width;
            public int Height;
            public char[] Cells;
            public string[] Styles;

            public WallCells(int width, int height)
            {
                Width = width;
                Height = height;
                Cells = new char[width * height];
                Styles = new string[width * height];
            }

            /// <summary>
            /// Takes the lines of a frame apart: every character that is seen is a cell, with the colours
            /// that were set when it was written. Hyperlinks and whatever else is not a colour are left out.
            /// </summary>
            public void Read(List<Line> lines)
            {
                for (int i = 0; i < Cells.Length; i++) Cells[i] = ' ';
                Array.Clear(Styles, 0, Styles.Length);
                for (int y = 0; y < Height && y < lines.Count; y++)
                {
                    string text = lines[y].Text ?? string.Empty;
                    string style = null;
                    int x = 0;
                    for (int i = 0; i < text.Length && x < Width; i++)
                    {
                        char c = text[i];
                        if (c != '\u001b')
                        {
                            Cells[y * Width + x] = c;
                            Styles[y * Width + x] = style;
                            x++;
                            continue;
                        }
                        if (i + 1 >= text.Length) break;
                        if (text[i + 1] == '[')
                        {
                            // A sequence that ends in a letter. One that ends in m sets the colours: the
                            // renderer writes all of them in one sequence, so the last one is what counts.
                            int end = i + 2;
                            while (end < text.Length && (text[end] < '@' || text[end] > '~')) end++;
                            if (end < text.Length && text[end] == 'm')
                            {
                                string set = text.Substring(i + 2, end - i - 2);
                                if (set.StartsWith("0;", StringComparison.Ordinal)) set = set.Substring(2);
                                style = set.Length == 0 || set == "0" ? null : set;
                            }
                            i = end;
                        }
                        else if (text[i + 1] == ']')
                        {
                            // A hyperlink, or a title: to its end, which is a bell or an escape and a backslash.
                            int end = i + 2;
                            while (end < text.Length && text[end] != '\u0007' && !(text[end] == '\u001b' && end + 1 < text.Length && text[end + 1] == '\\')) end++;
                            i = end < text.Length && text[end] == '\u001b' ? end + 1 : end;
                        }
                        else
                        {
                            i++;
                        }
                    }
                }
            }
        }

        /// <summary>The wall while it breaks: the dashboard as it was, where it breaks, and how far each cell is from there.</summary>
        private sealed class GameWall
        {
            public WallCells Wall;
            public WallCells Behind;
            public WallCells Frame;
            public double Time;
            public int Seed;
            public double X;
            public double Y;
            public double Reach;
            // For each cell: how far it is from where the wall breaks, with a cell twice as high as it is
            // wide, and how much sooner or later than that the hole is there, which makes its edge ragged.
            public float[] Far;
            public float[] Ragged;
            // For each cell on a crack: how far along the crack it is, and how the crack runs there.
            public float[] CrackAt;
            public char[] Crack;
        }

        private GameWall _gameWall;
        private bool _gameUnlocked;
        // The first time in a run, once the wall is gone, the splash is up: the game waits for a key under it.
        private bool _gameSplash;
        private bool _gameHelp;

        /// <summary>
        /// The game comes on screen at once: no wall that breaks, and no words after it. For the tests of
        /// the game itself.
        /// </summary>
        public bool GameSkipOpening { get; set; }

        /// <summary>The wall is breaking: the dashboard is still partly on screen. For tests.</summary>
        public bool IsGameOpening { get { lock (_gate) return _gameShown && _gameWall != null; } }

        /// <summary>The game waits for its first key: the splash is up, or about to come. For tests.</summary>
        public bool IsGameSplash { get { lock (_gate) return _gameShown && _gameSplash; } }

        // ------------------------------------------------------------------ the wall (callers hold _gate)

        /// <summary>A number from 0 to 1 for a cell, the same every time for the same seed.</summary>
        private static double WallNoise(int x, int y, int seed)
        {
            uint h = unchecked((uint)(x * 374761393 + y * 668265263 + seed * 362437));
            h = unchecked((h ^ (h >> 13)) * 1274126177);
            h ^= h >> 16;
            return (h & 0xFFFFFF) / 16777216.0;
        }

        /// <summary>
        /// Makes the wall of the frame of the dashboard, for a screen of this size. Where it breaks is
        /// somewhere in the middle of the screen; the cracks run from there in
        /// seven directions, each with a bend every few cells and a branch or two.
        /// </summary>
        private void StartGameWall(List<Line> dashboard, int width, int height)
        {
            var wall = new GameWall { Wall = new WallCells(width, height), Behind = new WallCells(width, height), Frame = new WallCells(width, height) };
            wall.Wall.Read(dashboard);
            wall.Seed = GameSeed != 0 ? GameSeed : Environment.TickCount;
            wall.X = width * (0.35 + 0.3 * WallNoise(1, 0, wall.Seed));
            wall.Y = height * (0.35 + 0.3 * WallNoise(2, 0, wall.Seed));
            int count = width * height;
            wall.Far = new float[count];
            wall.Ragged = new float[count];
            wall.CrackAt = new float[count];
            wall.Crack = new char[count];
            double turn1 = 6.283 * WallNoise(3, 0, wall.Seed);
            double turn2 = 6.283 * WallNoise(4, 0, wall.Seed);
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    double dx = x - wall.X;
                    double dy = 2 * (y - wall.Y);
                    double far = Math.Sqrt(dx * dx + dy * dy);
                    double angle = Math.Atan2(dy, dx);
                    wall.Far[y * width + x] = (float)far;
                    // The edge of the hole is nearer in some directions than in others, and uneven from cell to cell.
                    wall.Ragged[y * width + x] = (float)(2.6 * Math.Sin(3 * angle + turn1) + 1.6 * Math.Sin(7 * angle + turn2) + 3.2 * (WallNoise(x, y, wall.Seed) - 0.5));
                    wall.Reach = Math.Max(wall.Reach, far + 8);
                }
            }
            for (int k = 0; k < WallCracks; k++)
            {
                double angle = 6.283 * (k + 0.8 * WallNoise(5, k, wall.Seed)) / WallCracks;
                WallCrack(wall, wall.X, wall.Y, angle, 0, wall.Reach * 0.6, k * 16);
            }
            _gameWall = wall;
        }

        /// <summary>
        /// One crack: from a point in a direction, for a length, cell by cell. Every few cells it bends,
        /// and here and there a shorter one branches off it.
        /// </summary>
        private static void WallCrack(GameWall wall, double x, double y, double angle, double from, double length, int salt)
        {
            int width = wall.Wall.Width;
            int height = wall.Wall.Height;
            for (double at = 0; at < length; at += 0.5)
            {
                int bend = (int)(at / 4);
                if (at > 0 && Math.Abs(at / 4 - bend) < 1e-9)
                {
                    angle += 0.7 * (WallNoise(salt + bend, 6, wall.Seed) - 0.5);
                    if (salt < 1000 && bend % 3 == 2) WallCrack(wall, x, y, angle + (WallNoise(salt + bend, 7, wall.Seed) < 0.5 ? 0.8 : -0.8), from + at, 6 + 8 * WallNoise(salt + bend, 8, wall.Seed), 1000 + salt * 8 + bend);
                }
                x += 0.5 * Math.Cos(angle);
                y += 0.25 * Math.Sin(angle);
                int cx = (int)Math.Round(x);
                int cy = (int)Math.Round(y);
                if (cx < 0 || cy < 0 || cx >= width || cy >= height) return;
                int cell = cy * width + cx;
                if (wall.Crack[cell] != '\0') continue;
                double across = Math.Abs(Math.Cos(angle));
                double down = Math.Abs(Math.Sin(angle));
                wall.Crack[cell] = down < 0.38 ? '-' : (across < 0.38 ? '|' : (Math.Cos(angle) * Math.Sin(angle) > 0 ? '\\' : '/'));
                wall.CrackAt[cell] = (float)(from + at + 0.5);
            }
        }

        /// <summary>The wall is gone: the game is on screen, and the splash is on it at once.</summary>
        private void EndGameWall()
        {
            if (_gameWall == null) return;
            _gameWall = null;
            ShowGameSplash();
        }

        /// <summary>The splash is up, with the tune of the start, and the game waits for a key.</summary>
        private void ShowGameSplash()
        {
            _gameSplash = true;
            RequestTone(ToneIntro);
        }

        /// <summary>
        /// A frame of the breaking, from the frame of the game: the dashboard where the hole is not yet,
        /// with the cracks in it, rubble at the edge of the hole, the game inside it, and a little debris
        /// that falls from the edge.
        /// </summary>
        private List<Line> BuildWallScreen(List<Line> game, int width, int height, bool ansi)
        {
            var wall = _gameWall;
            var behind = wall.Behind;
            behind.Read(game);
            double time = wall.Time;
            // First the cracks, as far as a third of the way. Then the hole, slowly at first, with the
            // cracks ahead of it.
            bool cracks = time <= WallCrackSeconds;
            double part = cracks ? 0 : Math.Min(1, (time - WallCrackSeconds) / (WallSeconds - WallCrackSeconds));
            double hole = cracks ? -WallRim - 4 : wall.Reach * Math.Pow(part, 1.7);
            double cracked = cracks ? wall.Reach * 0.3 * Math.Pow(time / WallCrackSeconds, 0.7) : Math.Max(wall.Reach * 0.3, hole + 12);
            double rough = Math.Min(1, Math.Max(0, hole) / 8);
            string rubble = Unicode ? "▓▒░" : "#%:";
            int count = width * height;
            var cells = wall.Frame.Cells;
            var styles = wall.Frame.Styles;
            for (int i = 0; i < count; i++)
            {
                double edge = wall.Far[i] - rough * wall.Ragged[i];
                if (edge < hole)
                {
                    cells[i] = behind.Cells[i];
                    styles[i] = behind.Styles[i];
                }
                else if (edge < hole + WallRim)
                {
                    cells[i] = rubble[(int)(3 * WallNoise(i, 9, wall.Seed))];
                    styles[i] = WallRubble;
                }
                else if (wall.Crack[i] != '\0' && wall.CrackAt[i] <= cracked)
                {
                    cells[i] = wall.Crack[i];
                    styles[i] = WallCrackColour;
                }
                else
                {
                    cells[i] = wall.Wall.Cells[i];
                    styles[i] = wall.Wall.Styles[i];
                }
            }
            // Debris: pieces that come off the edge, one after the other, and fall for half a second.
            for (int k = 0; k < WallDebris; k++)
            {
                double born = WallCrackSeconds + (WallSeconds - WallCrackSeconds - 0.3) * WallNoise(k, 10, wall.Seed);
                double age = time - born;
                if (age < 0 || age > 0.5) continue;
                double angle = 6.283 * WallNoise(k, 11, wall.Seed);
                double at = wall.Reach * Math.Pow((born - WallCrackSeconds) / (WallSeconds - WallCrackSeconds), 1.7);
                int x = (int)Math.Round(wall.X + at * Math.Cos(angle) + 6 * (WallNoise(k, 12, wall.Seed) - 0.5) * age);
                int y = (int)Math.Round(wall.Y + at * Math.Sin(angle) / 2 + 30 * age * age);
                if (x < 0 || y < 0 || x >= width || y >= height) continue;
                cells[y * width + x] = rubble[Math.Min(2, (int)(age * 6))];
                styles[y * width + x] = WallRubble;
            }
            return CellLines(wall.Frame, ansi);
        }

        /// <summary>The lines of a frame of cells: a colour sequence where the colours change.</summary>
        private static List<Line> CellLines(WallCells frame, bool ansi)
        {
            int width = frame.Width;
            var cells = frame.Cells;
            var styles = frame.Styles;
            var lines = new List<Line>(frame.Height);
            var text = new StringBuilder(width + 64);
            for (int y = 0; y < frame.Height; y++)
            {
                int from = y * width;
                int end = width;
                while (end > 0 && cells[from + end - 1] == ' ' && styles[from + end - 1] == null) end--;
                string plain = new string(cells, from, end);
                if (!ansi)
                {
                    lines.Add(new Line { Text = plain, Plain = plain });
                    continue;
                }
                text.Length = 0;
                string style = null;
                for (int x = 0; x < end; x++)
                {
                    string want = styles[from + x];
                    if (!string.Equals(want, style, StringComparison.Ordinal))
                    {
                        text.Append(Esc).Append('0');
                        if (want != null) text.Append(';').Append(want);
                        text.Append('m');
                        style = want;
                    }
                    text.Append(cells[from + x]);
                }
                if (style != null) text.Append(Esc).Append("0m");
                lines.Add(new Line { Text = text.ToString(), Plain = plain });
            }
            return lines;
        }

        // ------------------------------------------------------------------ the words on the wall, and the help (callers hold _gate)

        /// <summary>
        /// Words on the wall of the game: lines in the middle of the sky, as if written there, with the
        /// letters that spell a word of their own in another colour: what is said when DC01 is gone.
        /// </summary>
        private void DrawGameWords(Canvas canvas, string[] lines)
        {
            // Where the counter of the run is otherwise: in the rows that nothing of the course is in,
            // where there are enough of them.
            int free = _game.SkyFree;
            int top = free >= lines.Length + 2 ? (free - lines.Length - 1) / 2 : Math.Max(1, (_game.Ground - 9) / 2 - 1);
            DrawGameWordsAt(canvas, lines, top);
        }

        /// <summary>The words on the wall from a row down, each line in the middle of the width.</summary>
        private void DrawGameWordsAt(Canvas canvas, string[] lines, int top)
        {
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i];
                int left = (canvas.Width - line.Length) / 2;
                canvas.Cover(left, top + i, line, GsWall);
                if (line.IndexOf("DE", StringComparison.Ordinal) < 0) continue;
                // DE and AD, and under each of them the paint that ran.
                foreach (string mark in new[] { "DE", "AD" })
                {
                    int at = line.IndexOf(mark, StringComparison.Ordinal);
                    canvas.Cover(left + at, top + i, mark, GsWallMark);
                    canvas.Put(left + at, top + i + 1, Unicode ? '╵' : '\'', GsWallMark);
                }
            }
        }

        /// <summary>
        /// The card of the help, over the playfield: what the game is, and its keys. On a screen that is
        /// too low for all of it, the lines about what is in the game are left out from the last one up.
        /// As the splash of the start, the first time in a run, its last line says that a key starts the
        /// game, and blinks.
        /// </summary>
        private void DrawGameHelp(Canvas canvas, bool start)
        {
            string foe = Unicode ? "▗█▖" : "/^\\";
            string coin = Unicode ? " ● " : " o ";
            string heart = Unicode ? " ♥ " : " * ";
            string rack = Unicode ? "▐▓▌" : "[#]";
            var lines = new List<string>
            {
                "MAESTER RUN",
                "You found it. This course is built live from your tenant's test results.",
                string.Empty,
                "  " + foe + " Failed tests come at you. Land on them to squash them.",
                "      (Sadly, that only fixes them in here.)",
                "  " + coin + " Passed tests are coins. A streak of them builds a bridge.",
                "  " + heart + " Three hits and you are out.",
                "  " + rack + " DC01 waits near the end. Decommission it.",
                string.Empty,
                "The better your tenant, the higher you can score.",
                "A perfect run on a perfect tenant is 10,000. Bragging rights only.",
                string.Empty,
                "  Space  jump, and again in the air       M    sound on/off",
                "  P      pause                            Esc  back to the dashboard",
                "  ?      this help",
                string.Empty,
                start ? "press any key to start" : "press any key to get back to it"
            };
            // What is in the game is in the lines 3 to 7, and the keys start at line 12.
            int about = 8;
            int keys = 12;
            while (lines.Count + 2 > canvas.Height && about > 3)
            {
                about--;
                keys--;
                lines.RemoveAt(about);
            }
            int inner = 0;
            foreach (var l in lines) inner = Math.Max(inner, l.Length);
            inner = Math.Min(inner + 4, canvas.Width - 2);
            int left = (canvas.Width - inner - 2) / 2;
            int top = Math.Max(0, (canvas.Height - lines.Count - 2) / 2);
            string h = Unicode ? "─" : "-";
            char v = Unicode ? '│' : '|';
            canvas.Cover(left, top, (Unicode ? "╭" : "+") + Repeat(h, inner) + (Unicode ? "╮" : "+"), GsCard);
            for (int i = 0; i < lines.Count; i++)
            {
                string text = lines[i].Length > inner - 4 ? lines[i].Substring(0, Math.Max(0, inner - 4)) : lines[i];
                bool last = i == lines.Count - 1;
                // The last line is in the middle; the others start at the left, as they are written.
                int pad = last ? (inner - text.Length) / 2 : 2;
                byte style = i == 0 ? GsCardTitle : (last || text.TrimStart().StartsWith("(", StringComparison.Ordinal) ? GsCardDim : GsNone);
                // On the splash the last line says how to start, and blinks.
                if (last && start) style = (_tick / 6) % 2 == 0 ? GsCardTitle : GsCardText;
                canvas.Cover(left + 1, top + 1 + i, new string(' ', pad) + text + new string(' ', Math.Max(0, inner - pad - text.Length)), style);
                canvas.Put(left, top + 1 + i, v, GsCard);
                canvas.Put(left + inner + 1, top + 1 + i, v, GsCard);
                int x = left + 1 + pad;
                // The signs before the lines: a creature in its colour, a coin, a heart.
                if (i >= 3 && i < about && text.Length > 5)
                {
                    string sign = text.Substring(2, 3);
                    if (sign == foe) canvas.Cover(x + 2, top + 1 + i, sign, GsHigh);
                    else if (sign == coin) canvas.Cover(x + 2, top + 1 + i, sign, GsCoin);
                    else if (sign == heart) canvas.Cover(x + 2, top + 1 + i, sign, GsHeart);
                    else if (sign == rack) canvas.Cover(x + 2, top + 1 + i, sign, GsBoss);
                }
                // The keys are bold, and what they do is not: two keys to a line.
                if (i >= keys && i < keys + 3)
                {
                    canvas.Cover(x + 2, top + 1 + i, text.Substring(2, Math.Min(5, text.Length - 2)), GsCardText);
                    if (text.Length > 46) canvas.Cover(x + 42, top + 1 + i, text.Substring(42, 3), GsCardText);
                }
            }
            canvas.Cover(left, top + lines.Count + 1, (Unicode ? "╰" : "+") + Repeat(h, inner) + (Unicode ? "╯" : "+"), GsCard);
        }
    }
}
