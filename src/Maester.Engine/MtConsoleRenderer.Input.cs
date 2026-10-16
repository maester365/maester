using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
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
                    if (!_open || !_fullScreen || _pauseDepth > 0 || !(_running || _gameShown)) return;
                }
                Interlocked.Increment(ref _keyPolls);
                if (Console.IsInputRedirected)
                {
                    _keysOff = true;
                    return;
                }
                // Not now, but the job may be brought back to the foreground.
                if (!InForeground()) return;
                for (int n = 0; n < KeysPerTick && Console.KeyAvailable; n++)
                {
                    var info = Console.ReadKey(true);
                    SendKey(info.Key, info.KeyChar);
                }
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
