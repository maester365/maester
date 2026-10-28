using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Maester.Engine
{
    /// <summary>
    /// The keyboard of the dashboard. With ReadKeys set, the tick of the timer takes the keys that were typed
    /// since the last one and hands them to HandleKey; SendKey hands over a key the same way, for tests.
    ///
    /// Keys are read only while the full-screen dashboard runs tests (or shows the game), from a console
    /// that is not redirected, and never by a renderer that writes somewhere else than the console. What is
    /// typed in that time is taken: it does not reach the prompt after the run. Ctrl+C is not a key here
    /// and stops the run as before. A console that cannot be read turns the reading off for the rest of
    /// the run: it must never fail the run or hold it up.
    ///
    /// The reading is done outside the lock of the renderer, by one thread at a time: a read that another
    /// reader of the console holds up then waits alone, and the frames go on.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const int KeysPerTick = 16;
        private const string GameWord = "dead";
        private const int GameWordGapMs = 2000;
        private const int GameIntervalMs = 50;
        private const double GameLongestFrame = 0.25;

        private readonly bool _console;
        private readonly Stopwatch _gameClock = new Stopwatch();
        private double _gameLast;
        private int _polling;
        private int _keyPolls;
        private volatile bool _keysOff;
        private int _wordAt;
        private long _wordTime;
        private long _keyClockAdvance;

        /// <summary>
        /// Read the keys that are typed while the dashboard runs tests. Off unless the caller turns it on,
        /// and without effect for a renderer that was given a writer: only the console has a keyboard.
        /// </summary>
        public bool ReadKeys { get; set; }

        /// <summary>
        /// Open a hyperlink of the dashboard with a plain click, where terminals want a modifier key with it
        /// (Cmd or Ctrl). While the tests run the dashboard asks the terminal for the clicks of the mouse
        /// (SGR reports, modes 1000 and 1006) and opens the link that was clicked itself. Text is then selected
        /// with Option (macOS) or Shift held. It needs ReadKeys and colour, and is off on Windows, whose
        /// console reports the mouse another way.
        /// </summary>
        public bool ClickLinks { get; set; }

        /// <summary>Opens a link that was clicked. Null for the browser of the system; tests set it.</summary>
        public Action<string> OpenLink { get; set; }

        private const string MouseOn = "\u001b[?1000h\u001b[?1006h";
        private const string MouseOff = "\u001b[?1006l\u001b[?1000l";
        // ESC [ < and "65;300;100" at most: a longer run of digits is not a report.
        private const int MouseReportLongest = 20;
        private readonly List<ConsoleKeyInfo> _input = new List<ConsoleKeyInfo>();
        private volatile bool _mouseOn;
        private volatile bool _mouseDrain;
        private int _pressColumn = -1;
        private int _pressRow = -1;

        /// <summary>
        /// Characters as if they were typed at the console, a report of the mouse among them as a terminal
        /// sends it. An escape that is left at the end is the Escape key. For tests.
        /// </summary>
        public void SendInput(string text)
        {
            if (string.IsNullOrEmpty(text)) return;
            foreach (char c in text)
            {
                var key = c == '\u001b' ? ConsoleKey.Escape : c == '\r' ? ConsoleKey.Enter : c == ' ' ? ConsoleKey.Spacebar : default(ConsoleKey);
                TakeInput(key, c);
            }
            if (_input.Count > 0 && _input.Count < 3) FlushInput();
        }

        /// <summary>The address of the hyperlink at a cell (from zero) of the dashboard for a console size, or null. For tests.</summary>
        public string GetLinkAt(int width, int height, int column, int row)
        {
            lock (_gate) return LinkAt(BuildScreen(width, height, true), column, row);
        }

        /// <summary>How often the console was asked for keys. For tests.</summary>
        public int KeyPollCount { get { return Volatile.Read(ref _keyPolls); } }

        /// <summary>A key, as if it was typed at the console. For tests.</summary>
        public void SendKey(ConsoleKey key, char keyChar)
        {
            lock (_gate)
            {
                try { HandleKey(key, keyChar); }
                catch (Exception) { DropGame(); /* A key that cannot be handled must not reach the run. */ }
            }
        }

        /// <summary>
        /// Moves the time of the keys and of the game on by <paramref name="seconds"/>, as the timer does
        /// with the time that passed. For tests, which run without the timer.
        /// </summary>
        public void AdvanceGame(double seconds)
        {
            if (!(seconds > 0)) return;
            lock (_gate)
            {
                _keyClockAdvance += (long)(seconds * 1000);
                StepGame(seconds);
            }
        }

        // ------------------------------------------------------------------ reading (on the timer, outside _gate)

        /// <summary>Takes the keys that wait at the console, a few at most, and handles each.</summary>
        private void PollKeys()
        {
            if (!_console || _keysOff || Interlocked.CompareExchange(ref _polling, 1, 0) != 0) return;
            try
            {
                lock (_gate)
                {
                    if (!_open || !_fullScreen || _pauseDepth > 0 || !(_running || _gameShown || _mouseDrain)) return;
                }
                Interlocked.Increment(ref _keyPolls);
                if (Console.IsInputRedirected)
                {
                    _keysOff = true;
                    return;
                }
                // Not now, but the job may be brought back to the foreground.
                if (!InForeground()) return;
                // The clicks of the mouse that came in before the terminal stopped reporting them are dropped,
                // with the keys typed with them, so that none reaches the prompt as text.
                if (_mouseDrain)
                {
                    DrainClicks();
                    return;
                }
                // A report of the mouse is read to its end, past the keys of one tick when it must be.
                for (int n = 0; (n < KeysPerTick || _input.Count > 0) && n < KeysPerTick * 4 && Console.KeyAvailable; n++)
                {
                    var info = Console.ReadKey(true);
                    TakeInput(info.Key, info.KeyChar);
                }
                // An escape with nothing after it is the Escape key.
                if (_input.Count > 0 && _input.Count < 3 && !Console.KeyAvailable) FlushInput();
            }
            catch (Exception)
            {
                // No console, or one that cannot be read: no keys for the rest of the run.
                _keysOff = true;
            }
            finally
            {
                Interlocked.Exchange(ref _polling, 0);
            }
        }

        // ------------------------------------------------------------------ the mouse (outside _gate)

        /// <summary>
        /// A character from the console. An escape starts what may be a report of the mouse (ESC [ &lt; button ;
        /// column ; row, then M for a press or m for a release): its characters are held until it ends, and
        /// whatever turns out not to be one goes on as the keys it was.
        /// </summary>
        private void TakeInput(ConsoleKey key, char c)
        {
            if (_input.Count == 0)
            {
                if (c == '\u001b' && ClickLinks) _input.Add(new ConsoleKeyInfo(c, key, false, false, false));
                else SendKey(key, c);
                return;
            }
            int at = _input.Count;
            if ((at == 1 && c == '[') || (at == 2 && c == '<') || (at >= 3 && at < MouseReportLongest && ((c >= '0' && c <= '9') || c == ';')))
            {
                _input.Add(new ConsoleKeyInfo(c, key, false, false, false));
                return;
            }
            if (at >= 3 && (c == 'M' || c == 'm'))
            {
                var report = new StringBuilder();
                for (int i = 3; i < _input.Count; i++) report.Append(_input[i].KeyChar);
                _input.Clear();
                var parts = report.ToString().Split(';');
                int button, column, row;
                if (parts.Length == 3 && int.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out button) &&
                    int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out column) &&
                    int.TryParse(parts[2], NumberStyles.None, CultureInfo.InvariantCulture, out row))
                {
                    string url;
                    lock (_gate) url = HandleMouse(button, column - 1, row - 1, c == 'M');
                    if (url != null) OpenClickedLink(url);
                }
                return;
            }
            FlushInput();
            TakeInput(key, c);
        }

        /// <summary>Reads and drops what waits at the console once the terminal stopped reporting the mouse.</summary>
        private void DrainClicks()
        {
            _mouseDrain = false;
            _input.Clear();
            try
            {
                if (!_console || Console.IsInputRedirected || !InForeground()) return;
                for (int n = 0; n < KeysPerTick * 8 && Console.KeyAvailable; n++) Console.ReadKey(true);
            }
            catch (Exception) { /* A console that cannot be read has nothing to drop. */ }
        }

        /// <summary>The characters held as the start of a report of the mouse, which was not one, as keys.</summary>
        private void FlushInput()
        {
            var held = _input.ToArray();
            _input.Clear();
            foreach (var info in held) SendKey(info.Key, info.KeyChar);
        }

        /// <summary>
        /// A press or a release of a button of the mouse at a cell of the screen (from zero). A click of the left
        /// button with no modifier key, pressed and released on the same cell, on a hyperlink of the dashboard
        /// gives the address of the link to open. The game and everything else take no clicks.
        /// </summary>
        private string HandleMouse(int button, int column, int row, bool press)
        {
            if (!_open || !_fullScreen || _gameShown || button != 0) return null;
            if (press)
            {
                _pressColumn = column;
                _pressRow = row;
                return null;
            }
            bool same = column == _pressColumn && row == _pressRow;
            _pressColumn = _pressRow = -1;
            return same ? LinkAt(BuildScreen(CurrentWidth(), CurrentHeight(), Ansi), column, row) : null;
        }

        /// <summary>The address of the hyperlink at a cell of a screen (from zero), or null where there is none.</summary>
        private static string LinkAt(List<Line> screen, int column, int row)
        {
            if (row < 0 || row >= screen.Count || column < 0) return null;
            string text = screen[row].Text ?? string.Empty;
            string url = null;
            int cell = 0;
            int i = 0;
            while (i < text.Length)
            {
                char c = text[i];
                if (c == '\u001b' && i + 1 < text.Length && text[i + 1] == ']')
                {
                    // An OSC sequence, to the bell or the string terminator: a hyperlink starts or ends.
                    int j = i + 2;
                    while (j < text.Length && text[j] != '\u0007' && text[j] != '\u001b') j++;
                    string body = text.Substring(i + 2, j - i - 2);
                    if (body.StartsWith("8;", StringComparison.Ordinal))
                    {
                        int semi = body.IndexOf(';', 2);
                        url = semi >= 0 && semi + 1 < body.Length ? body.Substring(semi + 1) : null;
                    }
                    i = j < text.Length && text[j] == '\u001b' ? j + 2 : j + 1;
                    continue;
                }
                if (c == '\u001b' && i + 1 < text.Length && text[i + 1] == '[')
                {
                    // A CSI sequence (colours, the cursor) takes no cell.
                    int j = i + 2;
                    while (j < text.Length && (text[j] < '@' || text[j] > '~')) j++;
                    i = j + 1;
                    continue;
                }
                // The second half of a surrogate pair is in the cell of the first.
                if (!char.IsLowSurrogate(c))
                {
                    if (cell == column) return url != null && IsSafeLink(url) ? url : null;
                    cell++;
                }
                i++;
            }
            return null;
        }

        /// <summary>Opens a link that was clicked, with OpenLink when it is set, else in the browser of the system.</summary>
        private void OpenClickedLink(string url)
        {
            try
            {
                var open = OpenLink;
                if (open != null)
                {
                    open(url);
                    return;
                }
                var start = new ProcessStartInfo(RuntimeInformation.IsOSPlatform(OSPlatform.OSX) ? "open" : "xdg-open")
                {
                    UseShellExecute = false,
                    // Whatever the opener says would land on the dashboard.
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                start.ArgumentList.Add(url);
                using (Process.Start(start)) { }
            }
            catch (Exception) { /* A link that cannot be opened must not reach the run. */ }
        }

        /// <summary>Whether the dashboard should take the clicks of the mouse for the tests it is about to run.</summary>
        private bool WantsClicks()
        {
            if (!ClickLinks || !ReadKeys || !_console || !Ansi || !_fullScreen) return false;
            if (Environment.OSVersion.Platform == PlatformID.Win32NT) return false;
            try { return !Console.IsInputRedirected; }
            catch (Exception) { return false; }
        }

        [DllImport("libc")]
        private static extern int tcgetpgrp(int fd);

        [DllImport("libc")]
        private static extern int getpgrp();

        /// <summary>
        /// Whether this process is the foreground job of its terminal. On Unix a background job that sets
        /// the terminal up for a read is stopped (SIGTTOU), and asking for a key does that: a run that was
        /// put in the background must go on, so it is not asked. Windows has no such thing.
        /// </summary>
        private static bool InForeground()
        {
            if (Environment.OSVersion.Platform == PlatformID.Win32NT) return true;
            return tcgetpgrp(0) == getpgrp();
        }

        // ------------------------------------------------------------------ keys (callers hold _gate)

        private long KeyClock() { return _clock.ElapsedMilliseconds + _keyClockAdvance; }

        /// <summary>
        /// A key. While the game is on screen it goes to the game. Otherwise the letters of the word that
        /// starts the game are counted: in order, in any case, with no other key and no more than two
        /// seconds between two of them, and only while tests run on the dashboard.
        /// </summary>
        private void HandleKey(ConsoleKey key, char keyChar)
        {
            if (!_open || !_fullScreen) return;
            char c = char.ToLowerInvariant(keyChar);
            if (_gameShown)
            {
                GameKey(key, c);
                PlayGameSounds();
                return;
            }
            if (!_running)
            {
                _wordAt = 0;
                return;
            }
            long now = KeyClock();
            bool next = c == GameWord[_wordAt] && (_wordAt == 0 || now - _wordTime <= GameWordGapMs);
            // A wrong letter starts the word again, with itself when it is the first letter.
            _wordAt = next ? _wordAt + 1 : (c == GameWord[0] ? 1 : 0);
            _wordTime = now;
            if (_wordAt < GameWord.Length) return;
            _wordAt = 0;
            ShowGame();
        }

        /// <summary>
        /// A key for the game: the jump, the pause, the sound, the help, and the way back to the
        /// dashboard. When the game is over and its card is up, Enter starts another.
        /// </summary>
        private void GameKey(ConsoleKey key, char c)
        {
            // Any key ends the breaking of the wall, and any key closes the help: the key does nothing else.
            if (_gameWall != null)
            {
                EndGameWall();
                return;
            }
            if (_gameHelp)
            {
                _gameHelp = false;
                return;
            }
            // The first time in a run the game waits for a key: any key starts it and does nothing else.
            if (_gameSplash && !_gameEnded)
            {
                if (key == ConsoleKey.Escape || c == '\u001b' || c == 'q')
                {
                    HideGame();
                    return;
                }
                if (c == 'm')
                {
                    _gameMuted = !_gameMuted;
                    return;
                }
                _gameSplash = false;
                return;
            }
            if (key == ConsoleKey.Escape || c == '\u001b' || (c == 'q' && !_gameEnded))
            {
                HideGame();
                return;
            }
            // The run is over: nothing but the way back.
            if (_gameEnded || _game == null) return;
            if (c == 'm')
            {
                _gameMuted = !_gameMuted;
                return;
            }
            if (_game.Over)
            {
                if ((key == ConsoleKey.Enter || c == '\r' || c == '\n') && _game.OverFor >= Runner.OverSeconds) PlayGameAgain();
                return;
            }
            if (c == '?' || c == 'h' || key == ConsoleKey.F1)
            {
                // The help: the game stands still under it.
                _gameHelp = true;
                return;
            }
            if (c == 'p')
            {
                _game.Paused = !_game.Paused;
                return;
            }
            if (key == ConsoleKey.UpArrow || key == ConsoleKey.Spacebar || c == ' ' || c == 'w')
            {
                _game.Jump();
            }
        }

        // ------------------------------------------------------------------ the game on screen (callers hold _gate)

        private static bool GameFits(int width, int height)
        {
            return width >= GameLeastWidth && height >= GameLeastHeight;
        }

        /// <summary>
        /// Puts the game on screen: a new one, or the one that was left, which goes on where it stopped.
        /// The first time in a run the dashboard is not just gone: it is a wall that breaks.
        /// </summary>
        private void ShowGame()
        {
            int width = CurrentWidth();
            int height = CurrentHeight();
            if (_gameBroken || !GameFits(width, height)) return;
            List<Line> dashboard = null;
            bool first = !_gameUnlocked && !GameSkipOpening;
            _gameUnlocked = true;
            if (first)
            {
                // The dashboard as it is on screen now.
                try { dashboard = BuildScreen(width, height, Ansi); }
                catch (Exception) { dashboard = null; }
            }
            if (_game == null)
            {
                _game = NewGame();
                _gameFed = 0;
                _gameSince = _runResults.Count;
                // The best score so far, for the first row: read from its file by another thread, so that a
                // slow disk holds nothing up.
                string path = GameBestPath;
                if (!_gameBestRead && !string.IsNullOrEmpty(path)) Task.Run(() => ReadGameBest(path));
            }
            _game.Paused = false;
            _gameShown = true;
            _gameEnded = false;
            _gameHelp = false;
            _gameClock.Restart();
            _gameLast = 0;
            RestartFrames();
            if (dashboard != null)
            {
                try
                {
                    StartGameWall(dashboard, Math.Max(1, width - 1), height);
                    RequestTone(ToneBreak);
                }
                catch (Exception)
                {
                    // No wall, then: the game is there at once, with the splash on it as after the wall.
                    _gameWall = null;
                    ShowGameSplash();
                }
            }
            ChangeTimer(GameIntervalMs);
            DrawNow();
        }

        /// <summary>Back to the dashboard. The game keeps its state and stands still until it is shown again.</summary>
        private void HideGame()
        {
            if (!_gameShown) return;
            _gameShown = false;
            _gameEnded = false;
            _gameHelp = false;
            _gameWall = null;
            _gameClock.Stop();
            ChangeTimer(RefreshIntervalMs);
            DrawNow();
        }

        /// <summary>The game failed: it is gone for the rest of the run, and the dashboard is drawn as if it never was.</summary>
        private void DropGame()
        {
            _gameBroken = true;
            _gameShown = false;
            _gameEnded = false;
            _gameHelp = false;
            _gameWall = null;
            _gameSplash = false;
            _game = null;
            _gameTop = null;
            ChangeTimer(RefreshIntervalMs);
        }

        /// <summary>The tests stopped running. A game that is on screen ends with a card and takes no more keys but Esc.</summary>
        private void EndGameWithRun()
        {
            _wordAt = 0;
            if (_game != null)
            {
                // What the run was for DC01 is said for good now, also for a game that is not on screen.
                RuleGameBoss();
                // The results that came too late for a runner that was running to the last are not held
                // against it: those that wait, and those that are still ahead on the course. Not more of
                // them than came since the game last stood still: what waited for the player is the player's.
                if (GameMoving())
                {
                    FeedGame();
                    _game.Forgiven = Math.Min(_game.Unmet, Math.Max(0, _runResults.Count - _gameSince));
                }
                _game.Ended = true;
            }
            if (_game == null || !_gameShown) return;
            _gameEnded = true;
            _gameHelp = false;
            _gameWall = null;
            _gameClock.Stop();
            if (!_game.Paused) RequestTone(ToneFinish);
            ChangeTimer(RefreshIntervalMs);
        }

        /// <summary>A new run: no game, and no results for one.</summary>
        private void ResetGame()
        {
            bool shown = _gameShown;
            _runResults.Clear();
            _game = null;
            _gameTop = null;
            _gameCount = 0;
            _gameUnlocked = false;
            _gameWall = null;
            _gameSplash = false;
            _gameHelp = false;
            _gameShown = false;
            _gameEnded = false;
            _gameFed = 0;
            _gameSince = 0;
            _gameBossRule = 0;
            ResetFrames();
            _gameNewBest = false;
            _wordAt = 0;
            if (shown) ChangeTimer(RefreshIntervalMs);
        }

        /// <summary>The game is drawn more often than the dashboard. Without ticks (tests) there is nothing to change.</summary>
        private void ChangeTimer(int intervalMs)
        {
            if (_ticker == null || RefreshIntervalMs <= 0) return;
            _ticker.Change(Math.Max(1, Math.Min(intervalMs, RefreshIntervalMs)));
        }

        /// <summary>The time that passed since the last frame, for the game. A late frame does not make it jump.</summary>
        private void StepGameClock()
        {
            double now = _gameClock.Elapsed.TotalSeconds;
            double seconds = Math.Min(GameLongestFrame, now - _gameLast);
            _gameLast = now;
            if (seconds > 0) StepGame(seconds);
        }

        private void StepGame(double seconds)
        {
            if (_game == null || !_gameShown || _gameEnded) return;
            try
            {
                int width = CurrentWidth();
                int height = CurrentHeight();
                // A window that became too small for the game shows the dashboard again.
                if (!GameFits(width, height))
                {
                    HideGame();
                    return;
                }
                // While the wall breaks the game does not move, and under the help it does not either.
                if (_gameWall != null)
                {
                    _gameWall.Time += seconds;
                    if (_gameWall.Time >= WallSeconds) EndGameWall();
                    return;
                }
                if (_gameHelp) return;
                // The first time, the game waits under the splash for a key.
                if (_gameSplash) return;
                _game.Layout(Math.Max(1, width - 1), height - GameFrameRows(width, height));
                FeedGame();
                _game.Step(seconds);
                PlayGameSounds();
            }
            catch (Exception)
            {
                DropGame();
            }
        }
    }
}
