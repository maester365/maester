using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;

namespace Maester.Engine
{
    /// <summary>
    /// The console output of an interactive run. Before and after the tests it shows one status line for the
    /// current phase ("Reading the tenant context…"), drawn when the phase changes. While the tests run it is a
    /// live region: two lines at the bottom of the console with the result counts, a progress bar and the
    /// test that is running, redrawn in place.
    ///
    /// It replaces Write-Progress in interactive runs: the host's progress pane finds its place by asking the
    /// terminal for the cursor position, and terminals that do not answer get the pane at the top of the screen.
    /// Nothing here reads the cursor position; the region is erased relative to where it was drawn.
    ///
    /// Only the region itself is written here. Everything that stays in the scrollback (result lines, replayed
    /// warnings) is written by PowerShell through the host, between Pause() and Resume(), so it reaches the
    /// information stream and transcripts like any other host output.
    ///
    /// Threading: a timer redraws the region so the elapsed time of a long test keeps moving while the
    /// pipeline thread is busy in the test. Every write takes one lock, and nothing is drawn while paused.
    /// </summary>
    public sealed class MtConsoleRenderer : IDisposable
    {
        private const string Esc = "\u001b[";
        private static readonly string[] UnicodeSpinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };
        private static readonly string[] AsciiSpinner = { "|", "/", "-", "\\" };

        private readonly object _gate = new object();
        private readonly TextWriter _writer;
        private readonly Stopwatch _clock = new Stopwatch();
        private readonly Stopwatch _testClock = new Stopwatch();
        private Timer _timer;
        private bool _running;
        private int _pauseDepth;
        private int[] _drawnLengths = new int[0];
        private int _tick;
        private int _lastPercent = -1;

        private int _total;
        private int _passed, _failed, _error, _investigate, _skipped, _other;
        private string _currentId;
        private string _currentTitle;
        private string _status;
        private bool _statusShown;

        /// <summary>Writes to the console.</summary>
        public MtConsoleRenderer() : this(Console.Out) { }

        /// <summary>Writes to the given writer (tests use a StringWriter).</summary>
        public MtConsoleRenderer(TextWriter writer)
        {
            _writer = writer ?? throw new ArgumentNullException(nameof(writer));
            Ansi = true;
            Unicode = true;
            RefreshIntervalMs = 100;
        }

        /// <summary>Colour the region. Without it only cursor movement and erase sequences are written.</summary>
        public bool Ansi { get; set; }

        /// <summary>Use Unicode symbols and the braille spinner; otherwise ASCII.</summary>
        public bool Unicode { get; set; }

        /// <summary>Also report progress to the terminal tab or taskbar with OSC 9;4.</summary>
        public bool TaskbarProgress { get; set; }

        /// <summary>Timer redraw interval. 0 turns the timer off (redraws only happen on events).</summary>
        public int RefreshIntervalMs { get; set; }

        /// <summary>Console width to use instead of the real one; 0 reads Console.WindowWidth.</summary>
        public int Width { get; set; }

        public int Total { get { lock (_gate) return _total; } }
        public int Finished { get { lock (_gate) return _passed + _failed + _error + _investigate + _skipped + _other; } }
        public int Passed { get { lock (_gate) return _passed; } }
        public int Failed { get { lock (_gate) return _failed; } }
        public int Errors { get { lock (_gate) return _error; } }
        public int Investigate { get { lock (_gate) return _investigate; } }
        public int Skipped { get { lock (_gate) return _skipped; } }
        public bool IsRunning { get { lock (_gate) return _running; } }

        /// <summary>Starts the region for a run of <paramref name="total"/> tests.</summary>
        public void Start(int total)
        {
            lock (_gate)
            {
                if (_running) return;
                _total = Math.Max(0, total);
                _passed = _failed = _error = _investigate = _skipped = _other = 0;
                _currentId = _currentTitle = null;
                if (_pauseDepth == 0) Write(ClearStatus());
                _status = null;
                _statusShown = false;
                _pauseDepth = 0;
                _drawnLengths = new int[0];
                _running = true;
                _clock.Restart();
                Write(Esc + "?25l"); // hide the cursor while the region is live
                Draw();
                if (RefreshIntervalMs > 0) _timer = new Timer(_ => OnTimer(), null, RefreshIntervalMs, RefreshIntervalMs);
            }
        }

        /// <summary>
        /// Shows the current phase. Outside a run it is one line, drawn now and left with the cursor at its start,
        /// so a line the host writes without pausing replaces it instead of following it. During a run it is shown
        /// on the second line while no test is running. Null erases it.
        /// </summary>
        public void ShowStatus(string text)
        {
            lock (_gate)
            {
                _status = string.IsNullOrEmpty(text) ? null : text;
                if (_pauseDepth > 0) return;
                if (_running) { Draw(); return; }
                Write(_status == null ? ClearStatus() : StatusFrame());
            }
        }

        /// <summary>A test started.</summary>
        public void ItemStarting(string id, string title)
        {
            lock (_gate)
            {
                _currentId = id;
                _currentTitle = title;
                _testClock.Restart();
                if (_running && _pauseDepth == 0) Draw();
            }
        }

        /// <summary>A test finished with a Maester result: Passed, Failed, Error, Investigate, Skipped or NotRun.</summary>
        public void ItemFinished(string result)
        {
            lock (_gate)
            {
                switch (result)
                {
                    case "Passed": _passed++; break;
                    case "Failed": _failed++; break;
                    case "Error": _error++; break;
                    case "Investigate": _investigate++; break;
                    case "Skipped": _skipped++; break;
                    default: _other++; break;
                }
                _currentId = _currentTitle = null;
                _testClock.Reset();
                if (_running && _pauseDepth == 0) Draw();
            }
        }

        /// <summary>Erases the region so the host can write lines. Calls nest; each needs a Resume().</summary>
        public void Pause()
        {
            lock (_gate)
            {
                if (_pauseDepth++ == 0) Write(_running ? Clear() : ClearStatus());
            }
        }

        /// <summary>Draws the region again after Pause().</summary>
        public void Resume()
        {
            lock (_gate)
            {
                if (_pauseDepth == 0) return;
                if (--_pauseDepth > 0) return;
                if (_running) Draw();
                else if (_status != null) Write(StatusFrame());
            }
        }

        /// <summary>Ends the live region (or erases the status line) and restores the cursor. Safe to call more than once.</summary>
        public void Stop()
        {
            Timer timer;
            lock (_gate)
            {
                if (!_running)
                {
                    if (_pauseDepth == 0) Write(ClearStatus());
                    _status = null;
                    _statusShown = false;
                    _pauseDepth = 0;
                    return;
                }
                _running = false;
                timer = _timer;
                _timer = null;
                var sb = new StringBuilder();
                if (_pauseDepth == 0) sb.Append(Clear());
                _pauseDepth = 0;
                _status = null;
                if (TaskbarProgress) sb.Append("\u001b]9;4;0;0\u0007");
                sb.Append(Esc).Append("0m").Append(Esc).Append("?25h");
                Write(sb.ToString());
                _clock.Stop();
            }
            if (timer != null) timer.Dispose();
        }

        public void Dispose()
        {
            Stop();
        }

        /// <summary>The visible text of the two lines for a given width, without colour. For tests and diagnostics.</summary>
        public string[] GetPlainFrame(int width)
        {
            lock (_gate)
            {
                var lines = BuildFrame(width, false);
                return new[] { lines[0].Plain, lines[1].Plain };
            }
        }

        // ------------------------------------------------------------------ drawing (callers hold _gate)

        private void OnTimer()
        {
            try
            {
                lock (_gate)
                {
                    if (!_running || _pauseDepth > 0) return;
                    _tick++;
                    Draw();
                }
            }
            catch (Exception)
            {
                // A console that went away (closed window, broken pipe) must not crash the process from a timer thread.
            }
        }

        private void Draw()
        {
            int width = CurrentWidth();
            var lines = BuildFrame(width, Ansi);
            var sb = new StringBuilder();
            sb.Append(Esc).Append("?2026h"); // synchronized output: terminals that support it paint the frame at once
            sb.Append(Clear());
            sb.Append(lines[0].Text).Append('\n').Append(lines[1].Text);
            sb.Append(Esc).Append("?2026l");
            if (TaskbarProgress)
            {
                int pct = _total > 0 ? (int)(100L * FinishedCount() / _total) : 0;
                if (pct != _lastPercent)
                {
                    sb.Append("\u001b]9;4;1;").Append(pct.ToString(CultureInfo.InvariantCulture)).Append('\u0007');
                    _lastPercent = pct;
                }
            }
            Write(sb.ToString());
            _drawnLengths = new[] { lines[0].Plain.Length, lines[1].Plain.Length };
        }

        /// <summary>
        /// Moves to the start of the region and erases it. A line drawn at an earlier, larger width may now wrap,
        /// so the number of rows is worked out from the current width.
        /// </summary>
        private string Clear()
        {
            if (_drawnLengths.Length == 0) return string.Empty;
            int width = CurrentWidth();
            int rows = 0;
            foreach (var len in _drawnLengths) rows += Math.Max(1, (len + width - 1) / width);
            var sb = new StringBuilder("\r").Append(Esc).Append("2K");
            for (int i = 1; i < rows; i++) sb.Append(Esc).Append("1A").Append(Esc).Append("2K");
            _drawnLengths = new int[0];
            return sb.ToString();
        }

        private string ClearStatus()
        {
            if (!_statusShown) return string.Empty;
            _statusShown = false;
            return "\r" + Esc + "2K";
        }

        private string StatusFrame()
        {
            int max = Math.Max(10, CurrentWidth() - 1);
            var line = new LineBuilder(Ansi).Add(Unicode ? "  › " : "  > ", "36").Add(_status + (Unicode ? "…" : "..."), "2").Build();
            var sb = new StringBuilder(ClearStatus());
            sb.Append(Truncate(line, max, Ansi).Text).Append('\r');
            _statusShown = true;
            return sb.ToString();
        }

        private struct FrameLine
        {
            public string Text;
            public string Plain;
        }

        private sealed class LineBuilder
        {
            private readonly StringBuilder _text = new StringBuilder();
            private readonly StringBuilder _plain = new StringBuilder();
            private readonly bool _ansi;
            public LineBuilder(bool ansi) { _ansi = ansi; }
            public int Length { get { return _plain.Length; } }
            public LineBuilder Add(string s, string sgr = null)
            {
                if (string.IsNullOrEmpty(s)) return this;
                if (_ansi && sgr != null) _text.Append(Esc).Append(sgr).Append('m').Append(s).Append(Esc).Append("0m");
                else _text.Append(s);
                _plain.Append(s);
                return this;
            }
            public FrameLine Build() { return new FrameLine { Text = _text.ToString(), Plain = _plain.ToString() }; }
        }

        private int FinishedCount() { return _passed + _failed + _error + _investigate + _skipped + _other; }

        private FrameLine[] BuildFrame(int width, bool ansi)
        {
            // Never write into the last column: some terminals wrap there, which breaks the erase.
            int max = Math.Max(10, width - 1);
            int done = FinishedCount();
            var elapsed = _clock.Elapsed;
            string ok = Unicode ? "✓" : "+", bad = Unicode ? "✗" : "x", err = "!", inv = "?", skip = Unicode ? "–" : "-";

            // Line 1: spinner, counts, bar, done/total, percent, elapsed and ETA.
            var counts = new LineBuilder(ansi);
            var spinner = Unicode ? UnicodeSpinner : AsciiSpinner;
            counts.Add(spinner[_tick % spinner.Length], "36").Add(" ");
            counts.Add(ok + " " + N(_passed), "32").Add("  ");
            counts.Add(bad + " " + N(_failed), _failed > 0 ? "31" : "2").Add("  ");
            counts.Add(err + " " + N(_error), _error > 0 ? "33" : "2").Add("  ");
            counts.Add(inv + " " + N(_investigate), _investigate > 0 ? "35" : "2").Add("  ");
            counts.Add(skip + " " + N(_skipped), "2");

            int pct = _total > 0 ? (int)(100L * done / _total) : 0;
            string tail = "  " + N(done) + "/" + N(_total) + "  " + pct.ToString(CultureInfo.InvariantCulture) + "%  " + Time(elapsed);
            if (done >= 5 && done < _total)
            {
                var eta = TimeSpan.FromTicks(elapsed.Ticks / done * (_total - done));
                tail += "  ETA " + Time(eta);
            }

            int barWidth = Math.Min(30, max - counts.Length - tail.Length - 2);
            var line1 = counts;
            if (barWidth >= 10)
            {
                int filled = _total > 0 ? (int)((long)barWidth * done / _total) : 0;
                line1.Add("  ");
                line1.Add(new string(Unicode ? '━' : '#', filled), "32");
                line1.Add(new string(Unicode ? '─' : '-', barWidth - filled), "2");
            }
            line1.Add(tail, "2");
            var first = Truncate(line1.Build(), max, ansi);

            // Line 2: the running test and how long it has run.
            var line2 = new LineBuilder(ansi);
            if (_currentId != null)
            {
                string time = " (" + Time(_testClock.Elapsed) + ")";
                line2.Add("  " + _currentId, "1");
                if (!string.IsNullOrEmpty(_currentTitle)) line2.Add("  " + _currentTitle);
                var built = Truncate(line2.Build(), max - time.Length, ansi);
                return new[] { first, Append(built, time, ansi) };
            }
            line2.Add("  " + (_status ?? "Running tests") + (Unicode ? "…" : "..."), "2");
            return new[] { first, Truncate(line2.Build(), max, ansi) };
        }

        private static FrameLine Append(FrameLine line, string suffix, bool ansi)
        {
            return new FrameLine
            {
                Text = line.Text + (ansi ? Esc + "2m" + suffix + Esc + "0m" : suffix),
                Plain = line.Plain + suffix
            };
        }

        /// <summary>Cuts a line to <paramref name="max"/> visible characters. Coloured lines are rebuilt from the plain text.</summary>
        private FrameLine Truncate(FrameLine line, int max, bool ansi)
        {
            if (line.Plain.Length <= max) return line;
            string ellipsis = Unicode ? "…" : ".";
            string cut = max > 1 ? line.Plain.Substring(0, max - 1) + ellipsis : line.Plain.Substring(0, Math.Max(0, max));
            // Colour is dropped from a cut line rather than risk splitting an escape sequence.
            return new FrameLine { Text = ansi ? Esc + "2m" + cut + Esc + "0m" : cut, Plain = cut };
        }

        private int CurrentWidth()
        {
            if (Width > 0) return Width;
            try
            {
                int w = Console.WindowWidth;
                return w > 0 ? w : 80;
            }
            catch (Exception)
            {
                return 80; // no console (redirected or a host without one)
            }
        }

        private void Write(string s)
        {
            if (string.IsNullOrEmpty(s)) return;
            _writer.Write(s);
            _writer.Flush();
        }

        private static string N(int n) { return n.ToString(CultureInfo.InvariantCulture); }

        private static string Time(TimeSpan t)
        {
            return t.TotalHours >= 1
                ? ((int)t.TotalHours).ToString(CultureInfo.InvariantCulture) + ":" + t.Minutes.ToString("00", CultureInfo.InvariantCulture) + ":" + t.Seconds.ToString("00", CultureInfo.InvariantCulture)
                : t.Minutes.ToString(CultureInfo.InvariantCulture) + ":" + t.Seconds.ToString("00", CultureInfo.InvariantCulture);
        }
    }
}
