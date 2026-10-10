using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;

namespace Maester.Engine
{
    /// <summary>
    /// The console output of an interactive run. It has two layouts.
    ///
    /// Full screen (a dashboard on the terminal's alternate screen, as less and vim use): a header, the phases of
    /// the run, and while tests run an overall bar, one lane per product and one line per running test, so it
    /// reads the same with one worker or many. Nothing it draws reaches the scrollback; lines that must stay
    /// (warnings, the summary) are written by PowerShell after Close() has restored the screen.
    ///
    /// Compact (a console too small for the dashboard, or when per-test lines are wanted): one status line for
    /// the current phase, and while tests run a two-line region at the bottom, redrawn in place. Host output is
    /// written between Pause() and Resume().
    ///
    /// It replaces Write-Progress in interactive runs: the host's progress pane finds its place by asking the
    /// terminal for the cursor position, and terminals that do not answer get the pane at the top of the screen.
    /// Nothing here reads the cursor position.
    ///
    /// Threading: a timer redraws so elapsed times keep moving while the pipeline thread is busy in a test, and
    /// results may arrive from several threads when tests run in parallel. Every call takes one lock.
    /// </summary>
    public sealed partial class MtConsoleRenderer : IDisposable
    {
        private const string Esc = "\u001b[";
        private const int MinFullScreenWidth = 80;
        private const int MinFullScreenHeight = 16;
        private static readonly string[] UnicodeSpinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };
        private static readonly string[] AsciiSpinner = { "|", "/", "-", "\\" };

        private sealed class Lane
        {
            public string Name;
            public string Note;
            public int Total, Passed, Failed, Error, Investigate, Skipped, Other, Running;
            public int Done { get { return Passed + Failed + Error + Investigate + Skipped + Other; } }
        }

        private sealed class Worker
        {
            public string Id;
            public string Title;
            public Lane Lane;
            public Stopwatch Clock;
        }

        private sealed class Phase
        {
            public string Name;
            public Stopwatch Clock;
            public bool Done;
        }

        private sealed class Line
        {
            public string Text;
            public string Plain;
        }

        private readonly object _gate = new object();
        private readonly TextWriter _writer;
        private readonly Stopwatch _clock = new Stopwatch();
        private readonly List<Lane> _lanes = new List<Lane>();
        private readonly List<Worker> _workers = new List<Worker>();
        private readonly List<Phase> _phases = new List<Phase>();
        private Timer _timer;
        private bool _open;
        private bool _fullScreen;
        private bool _running;
        private int _pauseDepth;
        private int[] _drawnLengths = new int[0];
        private int _tick;
        private int _lastPercent = -1;

        private int _total;
        private int _passed, _failed, _error, _investigate, _skipped, _other;
        private string _status;
        private bool _statusShown;
        private string[] _header;
        private int _headerWidth;
        private string _compactHeader;
        private int _taglineRow = -1;
        private string _taglinePrefix;
        private int _taglineWidth;
        private string _taglineVersion;
        private string _taglineSite;
        private string _taglineSiteUrl;
        private string _updateLabel;
        private string _updateUrl;
        private string _info;
        private int _infoLength;

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

        /// <summary>Colour the output. Without it only cursor movement and erase sequences are written.</summary>
        public bool Ansi { get; set; }

        /// <summary>Use Unicode symbols and the braille spinner; otherwise ASCII.</summary>
        public bool Unicode { get; set; }

        /// <summary>Also report progress to the terminal tab or taskbar with OSC 9;4.</summary>
        public bool TaskbarProgress { get; set; }

        /// <summary>Whether the terminal has 24-bit colour. Without it the status bar is one colour instead of a gradient.</summary>
        public bool TrueColor { get; set; }

        /// <summary>Timer redraw interval. 0 turns the timer off (redraws only happen on events).</summary>
        public int RefreshIntervalMs { get; set; }

        /// <summary>Console width to use instead of the real one; 0 reads Console.WindowWidth.</summary>
        public int Width { get; set; }

        /// <summary>Console height to use instead of the real one; 0 reads Console.WindowHeight.</summary>
        public int Height { get; set; }

        /// <summary>Use the full-screen dashboard when the console is large enough. Decided at Open().</summary>
        public bool FullScreen { get; set; }

        public int Total { get { lock (_gate) return _total; } }
        public int Finished { get { lock (_gate) return FinishedCount(); } }
        public int Passed { get { lock (_gate) return _passed; } }
        public int Failed { get { lock (_gate) return _failed; } }
        public int Errors { get { lock (_gate) return _error; } }
        public int Investigate { get { lock (_gate) return _investigate; } }
        public int Skipped { get { lock (_gate) return _skipped; } }

        /// <summary>Tests are running (between Start and Stop).</summary>
        public bool IsRunning { get { lock (_gate) return _running; } }

        /// <summary>The dashboard owns the screen (between Open and Close, in the full-screen layout).</summary>
        public bool IsFullScreen { get { lock (_gate) return _open && _fullScreen; } }

        // ------------------------------------------------------------------ content set by the caller

        /// <summary>
        /// The banner of the dashboard: lines that may contain colour, the columns they need, and a one-line
        /// replacement for consoles that are too narrow or too short for them.
        /// </summary>
        /// <summary>
        /// The tagline of the banner ("v3.0.0 · maester.dev"), which the renderer then writes itself so that it can
        /// add to it: <paramref name="row"/> of the header becomes <paramref name="prefix"/> followed by the
        /// tagline, right-aligned in <paramref name="width"/> columns. The site is a hyperlink.
        /// </summary>
        public void SetHeaderTagline(int row, string prefix, int width, string version, string site, string siteUrl)
        {
            lock (_gate)
            {
                _taglineRow = row;
                _taglinePrefix = prefix ?? string.Empty;
                _taglineWidth = width;
                _taglineVersion = version ?? string.Empty;
                _taglineSite = site ?? string.Empty;
                _taglineSiteUrl = siteUrl;
                Redraw();
            }
        }

        /// <summary>
        /// A newer version to mention in the tagline ("↑ v3.1.0 available"), as a hyperlink to where it can be had.
        /// Null removes it.
        /// </summary>
        public void SetHeaderUpdate(string label, string url)
        {
            lock (_gate)
            {
                _updateLabel = label;
                _updateUrl = url;
                Redraw();
            }
        }

        /// <summary>The tagline row of the banner: version, the update when there is one, and the site.</summary>
        private Line BuildTagline(bool ansi)
        {
            string dot = Unicode ? " · " : " - ";
            // A newer version stands out: an arrow in front of it, bold, in amber.
            string label = string.IsNullOrEmpty(_updateLabel) ? string.Empty : (Unicode ? "↑ " : "^ ") + _updateLabel;
            bool update = label.Length > 0 &&
                _taglineVersion.Length + label.Length + _taglineSite.Length + 2 * dot.Length <= _taglineWidth;
            // The site is in the status bar when there is one, and then not here as well.
            string site = _barLabels.Count > 0 ? string.Empty : _taglineSite;
            string plain = _taglineVersion + (update ? dot + label : string.Empty) + (site.Length > 0 ? dot + site : string.Empty);
            string pad = new string(' ', Math.Max(0, _taglineWidth - plain.Length));
            string prefixPlain = StripAnsi(_taglinePrefix);
            if (!ansi) return new Line { Text = prefixPlain + pad + plain, Plain = prefixPlain + pad + plain };
            var sb = new StringBuilder(_taglinePrefix).Append(pad);
            sb.Append(Esc).Append("2m").Append(_taglineVersion).Append(Esc).Append("0m");
            if (update)
            {
                sb.Append(Esc).Append("2m").Append(dot).Append(Esc).Append("0m");
                sb.Append(Esc).Append("1;38;5;215m").Append(Hyperlink(label, _updateUrl)).Append(Esc).Append("0m");
            }
            if (site.Length > 0) sb.Append(Esc).Append("2m").Append(dot).Append(Hyperlink(site, _taglineSiteUrl)).Append(Esc).Append("0m");
            return new Line { Text = sb.ToString(), Plain = prefixPlain + pad + plain };
        }

        public void SetHeader(string[] lines, int width, string compact)
        {
            lock (_gate)
            {
                _header = lines;
                _headerWidth = width;
                _compactHeader = compact;
                Redraw();
            }
        }

        /// <summary>The line under the banner (tenant and connections). It may contain colour; pass its visible length.</summary>
        public void SetInfo(string text, int visibleLength)
        {
            lock (_gate)
            {
                _info = text;
                _infoLength = visibleLength;
                Redraw();
            }
        }

        /// <summary>The phases of the run, in order.</summary>
        public void SetPhases(string[] names)
        {
            lock (_gate)
            {
                _phases.Clear();
                if (names != null) foreach (var n in names) _phases.Add(new Phase { Name = n });
                Redraw();
            }
        }

        /// <summary>Marks a phase as the current one; the phases before it are done.</summary>
        public void StartPhase(string name)
        {
            lock (_gate)
            {
                int index = _phases.FindIndex(p => string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase));
                if (index < 0) return;
                for (int i = 0; i < _phases.Count; i++)
                {
                    var p = _phases[i];
                    if (i < index)
                    {
                        if (p.Clock != null) p.Clock.Stop();
                        p.Done = true;
                    }
                    else if (i == index)
                    {
                        if (p.Clock == null) p.Clock = Stopwatch.StartNew();
                        p.Done = false;
                    }
                }
                _status = null;
                Redraw();
            }
        }

        // ------------------------------------------------------------------ lifecycle

        /// <summary>
        /// Takes over the screen for the dashboard when FullScreen is set and the console is large enough.
        /// Otherwise it does nothing and the compact layout is used.
        /// </summary>
        public void Open()
        {
            lock (_gate)
            {
                if (_open) return;
                _open = true;
                _clock.Restart();
                _fullScreen = FullScreen && CurrentWidth() >= MinFullScreenWidth && CurrentHeight() >= MinFullScreenHeight;
                if (!_fullScreen) return;
                Write(Esc + "?1049h" + Esc + "?25l"); // alternate screen, cursor hidden
                Draw();
                StartTimer();
            }
        }

        /// <summary>Starts the test phase for <paramref name="total"/> tests.</summary>
        public void Start(int total)
        {
            Start(total, null, null, null);
        }

        /// <summary>Starts the test phase with one lane per product: its name, the tests to run in it and an optional note.</summary>
        public void Start(int total, string[] laneNames, int[] laneTotals, string[] laneNotes)
        {
            lock (_gate)
            {
                if (_running) return;
                if (!_open) { _open = true; _clock.Restart(); }
                _total = Math.Max(0, total);
                _passed = _failed = _error = _investigate = _skipped = _other = 0;
                _lanes.Clear();
                _workers.Clear();
                if (laneNames != null)
                {
                    for (int i = 0; i < laneNames.Length; i++)
                    {
                        _lanes.Add(new Lane
                        {
                            Name = laneNames[i],
                            Total = laneTotals != null && i < laneTotals.Length ? laneTotals[i] : 0,
                            Note = laneNotes != null && i < laneNotes.Length ? laneNotes[i] : null
                        });
                    }
                }
                if (!_fullScreen)
                {
                    if (_pauseDepth == 0) Write(ClearStatus());
                    _statusShown = false;
                    _pauseDepth = 0;
                    _drawnLengths = new int[0];
                    Write(Esc + "?25l");
                }
                _status = null;
                ResetPanelState();
                _running = true;
                Draw();
                if (!_fullScreen) StartTimer();
            }
        }

        /// <summary>
        /// Shows what the current phase is doing. In the compact layout, outside a run, it is one line drawn now
        /// and left with the cursor at its start, so a line the host writes without pausing replaces it. Null erases it.
        /// </summary>
        public void ShowStatus(string text)
        {
            lock (_gate)
            {
                _status = string.IsNullOrEmpty(text) ? null : text;
                if (_fullScreen || _running) { Redraw(); return; }
                if (_pauseDepth > 0) return;
                Write(_status == null ? ClearStatus() : StatusFrame());
            }
        }

        /// <summary>A test started.</summary>
        public void ItemStarting(string id, string title)
        {
            ItemStarting(id, title, null);
        }

        /// <summary>A test started, in the lane of its product.</summary>
        public void ItemStarting(string id, string title, string lane)
        {
            lock (_gate)
            {
                var l = FindLane(lane);
                if (l != null) l.Running++;
                _workers.Add(new Worker { Id = id, Title = title, Lane = l, Clock = Stopwatch.StartNew() });
                Redraw();
            }
        }

        /// <summary>The oldest running test finished with a Maester result: Passed, Failed, Error, Investigate, Skipped or NotRun.</summary>
        public void ItemFinished(string result)
        {
            ItemFinished(null, result);
        }

        /// <summary>The test with this ID finished with a Maester result.</summary>
        public void ItemFinished(string id, string result)
        {
            ItemFinished(id, result, null);
        }

        /// <summary>The test with this ID finished with a Maester result; its severity feeds the Failed panel.</summary>
        public void ItemFinished(string id, string result, string severity)
        {
            Finish(id, result, severity, null);
        }

        /// <summary>
        /// The same, for a caller that measured the test itself: <paramref name="seconds"/> is how long it ran,
        /// instead of the time since ItemStarting.
        /// </summary>
        public void ItemFinished(string id, string result, string severity, double seconds)
        {
            Finish(id, result, severity, TimeSpan.FromSeconds(Math.Max(0, seconds)));
        }

        private void Finish(string id, string result, string severity, TimeSpan? measured)
        {
            lock (_gate)
            {
                int index = id == null ? (_workers.Count > 0 ? 0 : -1) : _workers.FindIndex(w => string.Equals(w.Id, id, StringComparison.OrdinalIgnoreCase));
                Lane lane = null;
                string title = null;
                var duration = TimeSpan.Zero;
                if (index >= 0)
                {
                    lane = _workers[index].Lane;
                    title = _workers[index].Title;
                    duration = _workers[index].Clock.Elapsed;
                    id = id ?? _workers[index].Id;
                    _workers.RemoveAt(index);
                    if (lane != null && lane.Running > 0) lane.Running--;
                }
                if (measured.HasValue) duration = measured.Value;
                RecordFinished(id, title, result, severity, duration);
                switch (result)
                {
                    case "Passed":
                        _passed++;
                        if (lane != null) lane.Passed++;
                        break;
                    case "Failed":
                        _failed++;
                        if (lane != null) lane.Failed++;
                        break;
                    case "Error":
                        _error++;
                        if (lane != null) lane.Error++;
                        break;
                    case "Investigate":
                        _investigate++;
                        if (lane != null) lane.Investigate++;
                        break;
                    case "Skipped":
                        _skipped++;
                        if (lane != null) lane.Skipped++;
                        break;
                    default:
                        _other++;
                        if (lane != null) lane.Other++;
                        break;
                }
                Redraw();
            }
        }

        /// <summary>
        /// Compact layout: erases the region or status line so the host can write lines; calls nest and each needs
        /// a Resume(). The dashboard owns its screen, so there it does nothing: callers keep such lines for later.
        /// </summary>
        public void Pause()
        {
            lock (_gate)
            {
                if (_fullScreen) return;
                if (_pauseDepth++ == 0) Write(_running ? Clear() : ClearStatus());
            }
        }

        /// <summary>Draws again after Pause().</summary>
        public void Resume()
        {
            lock (_gate)
            {
                if (_fullScreen || _pauseDepth == 0) return;
                if (--_pauseDepth > 0) return;
                if (_running) Draw();
                else if (_status != null) Write(StatusFrame());
            }
        }

        /// <summary>
        /// Ends the test phase. The compact layout erases its region and shows the cursor again; the dashboard
        /// stays on screen for the phases that follow, until Close(). Safe to call more than once.
        /// </summary>
        public void Stop()
        {
            Timer timer = null;
            lock (_gate)
            {
                if (!_running)
                {
                    if (!_fullScreen)
                    {
                        if (_pauseDepth == 0) Write(ClearStatus());
                        _status = null;
                        _statusShown = false;
                        _pauseDepth = 0;
                    }
                    return;
                }
                _running = false;
                _runClock.Stop();
                _workers.Clear();
                foreach (var l in _lanes) l.Running = 0;
                _status = null;
                if (_fullScreen) { Draw(); return; }

                timer = _timer;
                _timer = null;
                var sb = new StringBuilder();
                if (_pauseDepth == 0) sb.Append(Clear());
                _pauseDepth = 0;
                if (TaskbarProgress) sb.Append("\u001b]9;4;0;0\u0007");
                sb.Append(Esc).Append("0m").Append(Esc).Append("?25h");
                Write(sb.ToString());
            }
            if (timer != null) timer.Dispose();
        }

        /// <summary>Ends the run: restores the screen the dashboard took over, and the cursor. Safe to call more than once.</summary>
        public void Close()
        {
            Stop();
            Timer timer;
            lock (_gate)
            {
                if (!_open) return;
                _open = false;
                timer = _timer;
                _timer = null;
                if (_fullScreen)
                {
                    var sb = new StringBuilder();
                    if (TaskbarProgress) sb.Append("\u001b]9;4;0;0\u0007");
                    sb.Append(Esc).Append("0m").Append(Esc).Append("?25h").Append(Esc).Append("?1049l");
                    Write(sb.ToString());
                    _fullScreen = false;
                }
                _clock.Stop();
            }
            if (timer != null) timer.Dispose();
        }

        public void Dispose()
        {
            Close();
        }

        /// <summary>The visible text of the two lines of the compact region for a width, without colour. For tests.</summary>
        public string[] GetPlainFrame(int width)
        {
            lock (_gate)
            {
                var lines = BuildRegion(width, false);
                return new[] { lines[0].Plain, lines[1].Plain };
            }
        }

        /// <summary>The visible text of the dashboard for a console size, without colour. For tests.</summary>
        public string[] GetPlainScreen(int width, int height)
        {
            lock (_gate)
            {
                var lines = BuildScreen(width, height, false);
                var result = new string[lines.Count];
                for (int i = 0; i < lines.Count; i++) result[i] = lines[i].Plain;
                return result;
            }
        }

        // ------------------------------------------------------------------ drawing (callers hold _gate)

        private void StartTimer()
        {
            if (RefreshIntervalMs > 0 && _timer == null) _timer = new Timer(_ => OnTimer(), null, RefreshIntervalMs, RefreshIntervalMs);
        }

        private void OnTimer()
        {
            try
            {
                lock (_gate)
                {
                    if (!_open || _pauseDepth > 0) return;
                    if (!_fullScreen && !_running) return;
                    _tick++;
                    Draw();
                }
            }
            catch (Exception)
            {
                // A console that went away (closed window, broken pipe) must not crash the process from a timer thread.
            }
        }

        /// <summary>Draws when something is on screen to update: the dashboard, or the compact region during a run.</summary>
        private void Redraw()
        {
            if (!_open) return;
            if (_fullScreen || (_running && _pauseDepth == 0)) Draw();
        }

        private void Draw()
        {
            var sb = new StringBuilder();
            sb.Append(Esc).Append("?2026h"); // synchronized output: terminals that support it paint the frame at once
            if (_fullScreen)
            {
                var lines = BuildScreen(CurrentWidth(), CurrentHeight(), Ansi);
                sb.Append(Esc).Append('H');
                for (int i = 0; i < lines.Count; i++)
                {
                    sb.Append(lines[i].Text).Append(Esc).Append('K');
                    if (i < lines.Count - 1) sb.Append("\r\n");
                }
                sb.Append(Esc).Append('J');
            }
            else
            {
                var lines = BuildRegion(CurrentWidth(), Ansi);
                sb.Append(Clear());
                sb.Append(lines[0].Text).Append('\n').Append(lines[1].Text);
                _drawnLengths = new[] { lines[0].Plain.Length, lines[1].Plain.Length };
            }
            sb.Append(Esc).Append("?2026l");
            if (TaskbarProgress && _running)
            {
                int pct = _total > 0 ? (int)(100L * FinishedCount() / _total) : 0;
                if (pct != _lastPercent)
                {
                    sb.Append("\u001b]9;4;1;").Append(N(pct)).Append('\u0007');
                    _lastPercent = pct;
                }
            }
            Write(sb.ToString());
        }

        /// <summary>
        /// Compact layout: moves to the start of the region and erases it. A line drawn at an earlier, larger width
        /// may now wrap, so the number of rows is worked out from the current width.
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
            var line = new LineBuilder(Ansi).Add(Unicode ? "  › " : "  > ", "36").Add(_status + Ellipsis(), "2").Build();
            var sb = new StringBuilder(ClearStatus());
            sb.Append(Truncate(line, max, Ansi).Text).Append('\r');
            _statusShown = true;
            return sb.ToString();
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
            /// <summary>Text that is a hyperlink (OSC 8) to <paramref name="url"/> when colour is on and there is an address.</summary>
            public LineBuilder AddLink(string s, string url, string sgr = null)
            {
                if (string.IsNullOrEmpty(s)) return this;
                if (!_ansi || string.IsNullOrEmpty(url)) return Add(s, sgr);
                if (sgr != null) _text.Append(Esc).Append(sgr).Append('m');
                _text.Append(Hyperlink(s, url));
                if (sgr != null) _text.Append(Esc).Append("0m");
                _plain.Append(s);
                return this;
            }

            public Line Build() { return new Line { Text = _text.ToString(), Plain = _plain.ToString() }; }
        }

        private int FinishedCount() { return _passed + _failed + _error + _investigate + _skipped + _other; }

        private Lane FindLane(string name)
        {
            if (string.IsNullOrEmpty(name)) return null;
            foreach (var l in _lanes) if (string.Equals(l.Name, name, StringComparison.OrdinalIgnoreCase)) return l;
            return null;
        }

        private string Ok { get { return Unicode ? "✓" : "+"; } }
        private string Bad { get { return Unicode ? "✗" : "x"; } }
        private string Dash { get { return Unicode ? "–" : "-"; } }
        private string Ellipsis() { return Unicode ? "…" : "..."; }
        private string Spinner() { var s = Unicode ? UnicodeSpinner : AsciiSpinner; return s[_tick % s.Length]; }

        private void AddCounts(LineBuilder b, int passed, int failed, int error, int investigate, int skipped)
        {
            b.Add(Ok + " " + N(passed), "32").Add("  ");
            b.Add(Bad + " " + N(failed), failed > 0 ? "31" : "2").Add("  ");
            b.Add("! " + N(error), error > 0 ? "33" : "2").Add("  ");
            b.Add("? " + N(investigate), investigate > 0 ? "35" : "2").Add("  ");
            b.Add(Dash + " " + N(skipped), "2");
        }

        private void AddBar(LineBuilder b, int done, int total, int width)
        {
            int filled = total > 0 ? (int)Math.Min(width, (long)width * done / total) : 0;
            b.Add(new string(Unicode ? '━' : '#', filled), "32");
            b.Add(new string(Unicode ? '─' : '-', width - filled), "2");
        }

        /// <summary>done/total, percent and, once there is something to go on, the estimated time left.</summary>
        private string ProgressText(int done, Stopwatch clock, bool withElapsed)
        {
            int pct = _total > 0 ? (int)(100L * done / _total) : 0;
            string text = N(done) + "/" + N(_total) + "  " + N(pct) + "%";
            if (withElapsed) text += "  " + Time(clock.Elapsed);
            if (done >= 5 && done < _total) text += "  ETA " + Time(TimeSpan.FromTicks(clock.Elapsed.Ticks / done * (_total - done)));
            return text;
        }

        private Stopwatch CurrentPhaseClock()
        {
            foreach (var p in _phases) if (!p.Done && p.Clock != null) return p.Clock;
            return _clock;
        }

        // ---- compact layout: two lines

        private Line[] BuildRegion(int width, bool ansi)
        {
            // Never write into the last column: some terminals wrap there, which breaks the erase.
            int max = Math.Max(10, width - 1);
            int done = FinishedCount();

            var counts = new LineBuilder(ansi);
            counts.Add(Spinner(), "36").Add(" ");
            AddCounts(counts, _passed, _failed, _error, _investigate, _skipped);
            string tail = "  " + ProgressText(done, _clock, true);

            int barWidth = Math.Min(30, max - counts.Length - tail.Length - 2);
            if (barWidth >= 10)
            {
                counts.Add("  ");
                AddBar(counts, done, _total, barWidth);
            }
            counts.Add(tail, "2");
            var first = Truncate(counts.Build(), max, ansi);

            var line2 = new LineBuilder(ansi);
            if (_workers.Count > 0)
            {
                var w = _workers[0];
                string time = " (" + Time(w.Clock.Elapsed) + ")" + (_workers.Count > 1 ? " +" + N(_workers.Count - 1) + " more" : string.Empty);
                line2.Add("  " + w.Id, "1");
                if (!string.IsNullOrEmpty(w.Title)) line2.Add("  " + w.Title);
                var built = Truncate(line2.Build(), max - time.Length, ansi);
                return new[] { first, new Line { Text = built.Text + (ansi ? Esc + "2m" + time + Esc + "0m" : time), Plain = built.Plain + time } };
            }
            line2.Add("  " + (_status ?? "Running tests") + Ellipsis(), "2");
            return new[] { first, Truncate(line2.Build(), max, ansi) };
        }

        // ---- full-screen layout: the dashboard

        /// <summary>
        /// The whole screen: the content in all rows but the last of the window, and the status bar, when there is
        /// one, on the last row.
        /// </summary>
        private List<Line> BuildScreen(int width, int height, bool ansi)
        {
            int rows = Math.Max(8, height - 1);
            var screen = BuildContent(width, rows, ansi);
            if (_barLabels.Count == 0) return screen;
            while (screen.Count < rows) screen.Add(new Line { Text = string.Empty, Plain = string.Empty });
            screen.Add(BuildStatusBar(width, ansi));
            return screen;
        }

        private List<Line> BuildContent(int width, int rows, bool ansi)
        {
            // On a wide console the panels take a column on the right, and the two columns share the whole width.
            int paneWidth = PaneWidth(width);
            int mainWidth = width - 1 - PaneGap - paneWidth;
            int max = paneWidth > 0 ? mainWidth - 1 : Math.Max(20, width - 1);
            Func<Line> blank = () => new Line { Text = string.Empty, Plain = string.Empty };
            bool tests = _running || _total > 0;
            bool info = _info != null;

            // The phases of the run, on one line.
            Line phases = null;
            if (_phases.Count > 0)
            {
                var strip = new LineBuilder(ansi).Add(" ");
                for (int i = 0; i < _phases.Count; i++)
                {
                    var p = _phases[i];
                    if (p.Done) strip.Add(Ok, "32").Add(" " + p.Name + (p.Clock != null ? " " + Short(p.Clock.Elapsed) : string.Empty), "2");
                    else if (p.Clock != null) strip.Add(Unicode ? "●" : "*", "38;5;215").Add(" " + p.Name, "1").Add(" " + Short(p.Clock.Elapsed), "38;5;215");
                    else strip.Add(Unicode ? "○" : "o", "2").Add(" " + p.Name, "2");
                    if (i < _phases.Count - 1) strip.Add(Unicode ? "  ─  " : "  -  ", "2");
                }
                phases = Truncate(strip.Build(), max, ansi);
            }

            // Before the tests start the phases have a line under the banner. Once they run, the phases are in
            // the header line and the overall progress is here.
            var body = new List<Line>();
            if (!tests && phases != null)
            {
                body.Add(phases);
                body.Add(blank());
            }
            if (tests)
            {
                int done = FinishedCount();
                var overall = new LineBuilder(ansi).Add(" ");
                AddBar(overall, done, _total, Math.Max(10, Math.Min(40, max - 52) + Math.Max(0, max - (MainWidth - 1))));
                overall.Add("  " + ProgressText(done, CurrentPhaseClock(), false), "1").Add("   ");
                AddCounts(overall, _passed, _failed, _error, _investigate, _skipped);
                body.Add(Truncate(overall.Build(), max, ansi));
                body.Add(blank());
            }

            // What is running now: one line per test, so it reads the same with one worker or many.
            var tail = new List<Line>();
            if (_running)
            {
                tail.Add(new LineBuilder(ansi).Add(" Running", "1").Add(_workers.Count > 1 ? " · " + N(_workers.Count) + " tests" : string.Empty, "2").Build());
                foreach (var w in _workers)
                {
                    string time = Short(w.Clock.Elapsed).PadLeft(7);
                    var b = new LineBuilder(ansi).Add(" " + Spinner() + " ", "36").Add((w.Id ?? string.Empty).PadRight(17) + " ", "1").Add(w.Title);
                    var cut = Truncate(b.Build(), max - time.Length - 1, ansi);
                    string gap = new string(' ', Math.Max(1, max - time.Length - cut.Plain.Length));
                    tail.Add(new Line { Text = cut.Text + gap + (ansi ? Esc + "2m" + time + Esc + "0m" : time), Plain = cut.Plain + gap + time });
                }
                if (_workers.Count == 0) tail.Add(new LineBuilder(ansi).Add(" " + Spinner() + " ", "36").Add((_status ?? "Starting the next test") + Ellipsis(), "2").Build());
            }
            else if (_status != null)
            {
                tail.Add(new LineBuilder(ansi).Add(" " + Spinner() + " ", "36").Add(_status + Ellipsis()).Build());
            }

            // Header. While the run prepares: the banner, when it fits next to everything else. Once the tests
            // start the banner makes room for them: one line with the name, the version and the phases.
            var header = new List<Line>();
            int lanesWanted = tests ? _lanes.Count : 0;
            int needed = body.Count + tail.Count + 2 + (info ? 1 : 0);
            if (tests)
            {
                header.AddRange(BuildRunHeader(max, phases, ansi));
            }
            else if (_header != null && max >= _headerWidth && rows >= _header.Length + needed)
            {
                for (int i = 0; i < _header.Length; i++)
                {
                    string h = _header[i];
                    header.Add(i == _taglineRow ? BuildTagline(ansi) : new Line { Text = ansi ? h : StripAnsi(h), Plain = StripAnsi(h) });
                }
            }
            else if (_compactHeader != null)
            {
                header.Add(Truncate(new LineBuilder(ansi).Add(" " + _compactHeader, "1").Build(), max, ansi));
            }
            if (info)
            {
                string plainInfo = StripAnsi(_info);
                header.Add(_infoLength <= max
                    ? new Line { Text = ansi ? _info : plainInfo, Plain = plainInfo }
                    : Truncate(new Line { Text = plainInfo, Plain = plainInfo }, max, ansi));
            }
            header.Add(blank());

            // Lanes take the rows that are left; when there is not room for all, the ones with work left stay.
            var lanes = new List<Line>();
            int room = rows - header.Count - body.Count - tail.Count - 1;
            if (lanesWanted > 0 && room >= 2)
            {
                var shown = new List<Lane>(_lanes);
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
                    shown.Sort((a, b) => _lanes.IndexOf(a).CompareTo(_lanes.IndexOf(b)));
                }
                int nameWidth = 8;
                foreach (var l in shown) nameWidth = Math.Max(nameWidth, Math.Min(18, l.Name.Length));
                // Up to the standard width the bars are at most 24 columns; a wider column gives them the extra.
                int barWidth = Math.Max(8, Math.Min(24, max - nameWidth - 52) + Math.Max(0, max - (MainWidth - 1)));
                foreach (var l in shown)
                {
                    bool active = l.Done > 0 || l.Running > 0;
                    var b = new LineBuilder(ansi).Add(" ").Add(Fit(l.Name, nameWidth).PadRight(nameWidth + 1), active ? "1" : "2");
                    AddBar(b, l.Done, l.Total, barWidth);
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
                    if (l.Running > 0) b.Add(" " + N(l.Running) + " running", "38;5;215");
                    else if (!string.IsNullOrEmpty(l.Note)) b.Add(" " + l.Note, "2");
                    else if (l.Done == 0 && l.Total > 0 && _running) b.Add(" waiting", "2");
                    lanes.Add(Truncate(b.Build(), max, ansi));
                }
                if (hidden > 0) lanes.Add(new LineBuilder(ansi).Add(" " + Ellipsis() + " and " + N(hidden) + " more", "2").Build());
                lanes.Add(blank());
            }

            // Under the lanes: the Pace graph, when there are rows for it next to the result blocks and a few of
            // the tests that ran (two to five rows of graph, and the line that says what it shows).
            int free = rows - header.Count - body.Count - lanes.Count - tail.Count - 1;
            var pace = new List<Line>();
            if (tests && PanelShown(PacePanel) && free >= 10)
            {
                pace = BuildPaceSection(max, Math.Max(PaceGraphLeast, Math.Min(PaceGraphMost, free - 8)), ansi);
                pace.Add(blank());
            }

            // The results chart takes rows that are still free.
            var chart = tests ? BuildResultsChart(max, free - pace.Count, ansi) : new List<Line>();
            if (chart.Count > 0) chart.Add(blank());

            var screen = new List<Line>();
            screen.AddRange(header);
            screen.AddRange(body);
            screen.AddRange(lanes);
            screen.AddRange(pace);
            screen.AddRange(chart);
            screen.AddRange(tail);
            // The rows that are left under the running tests list the tests that ran before them.
            if (tests && screen.Count < rows) screen.AddRange(BuildRecent(max, rows - screen.Count, ansi));
            if (screen.Count > rows) screen.RemoveRange(rows, screen.Count - rows);
            if (paneWidth > 0)
            {
                var pane = BuildPane(paneWidth, rows, ansi);
                if (pane.Count > 0) return Beside(screen, pane, mainWidth, rows);
            }
            return screen;
        }

        /// <summary>
        /// The header while tests run: the name in the colours of the wordmark, the version, a newer version
        /// when there is one, and the phases at the right of the same line (on a line of their own when they do
        /// not fit next to the name).
        /// </summary>
        private List<Line> BuildRunHeader(int max, Line phases, bool ansi)
        {
            var lines = new List<Line>();
            LineBuilder b = null;
            if (!string.IsNullOrEmpty(_taglineVersion))
            {
                b = new LineBuilder(ansi).Add(" ");
                const string name = "MAESTER";
                for (int i = 0; i < name.Length; i++) b.Add(name[i].ToString(), WordmarkColour(i, name.Length));
                b.Add(" " + _taglineVersion, "2");
                if (!string.IsNullOrEmpty(_updateLabel))
                {
                    b.Add(Unicode ? " · " : " - ", "2").AddLink((Unicode ? "↑ " : "^ ") + _updateLabel, _updateUrl, "1;38;5;215");
                }
            }
            else if (_compactHeader != null)
            {
                b = new LineBuilder(ansi).Add(" " + _compactHeader, "1");
            }
            if (b == null)
            {
                if (phases != null) lines.Add(phases);
                return lines;
            }
            var name0 = Truncate(b.Build(), max, ansi);
            if (phases != null && name0.Plain.Length + 2 + phases.Plain.Length <= max)
            {
                string gap = new string(' ', max - name0.Plain.Length - phases.Plain.Length);
                lines.Add(new Line { Text = name0.Text + gap + phases.Text, Plain = name0.Plain + gap + phases.Plain });
                return lines;
            }
            lines.Add(name0);
            if (phases != null) lines.Add(phases);
            return lines;
        }

        /// <summary>The colour of a letter of the name: the gradient of the wordmark, Maester red to amber.</summary>
        private string WordmarkColour(int index, int count)
        {
            if (!TrueColor) return "1;38;5;208";
            double t = count > 1 ? (double)index / (count - 1) * (BarStops.Length - 1) : 0;
            int segment = Math.Min((int)t, BarStops.Length - 2);
            var rgb = new int[3];
            for (int i = 0; i < 3; i++) rgb[i] = (int)(BarStops[segment][i] + (BarStops[segment + 1][i] - BarStops[segment][i]) * (t - segment));
            return "1;38;2;" + N(rgb[0]) + ";" + N(rgb[1]) + ";" + N(rgb[2]);
        }

        private static string Fit(string s, int width)
        {
            if (s == null) return string.Empty;
            return s.Length <= width ? s : s.Substring(0, Math.Max(0, width - 1)) + ".";
        }

        /// <summary>Removes SGR and OSC sequences, to measure a line or to draw it without colour.</summary>
        private static string StripAnsi(string s)
        {
            if (string.IsNullOrEmpty(s) || s.IndexOf('\u001b') < 0) return s ?? string.Empty;
            var sb = new StringBuilder(s.Length);
            int i = 0;
            while (i < s.Length)
            {
                if (s[i] != '\u001b')
                {
                    sb.Append(s[i]);
                    i++;
                    continue;
                }
                i = SequenceEnd(s, i);
            }
            return sb.ToString();
        }

        /// <summary>
        /// Cuts a line to <paramref name="max"/> visible characters and ends it with an ellipsis. The colours and
        /// hyperlinks of the part that is kept stay: escape sequences are copied whole, never split.
        /// </summary>
        private Line Truncate(Line line, int max, bool ansi)
        {
            if (line.Plain.Length <= max) return line;
            string mark = Unicode ? "…" : ".";
            string cut = max > 1 ? line.Plain.Substring(0, max - 1) + mark : line.Plain.Substring(0, Math.Max(0, max));
            if (!ansi || max <= 1 || line.Text.IndexOf('\u001b') < 0) return new Line { Text = cut, Plain = cut };

            var sb = new StringBuilder(line.Text.Length);
            string text = line.Text;
            int visible = 0;
            int i = 0;
            bool linkOpen = false;
            while (i < text.Length && visible < max - 1)
            {
                if (text[i] != '\u001b')
                {
                    sb.Append(text[i]);
                    visible++;
                    i++;
                    continue;
                }
                int end = SequenceEnd(text, i);
                // OSC 8 opens a hyperlink when it names a target, and closes one when it does not.
                if (end - i > 5 && string.CompareOrdinal(text, i, Esc8, 0, Esc8.Length) == 0) linkOpen = text[i + Esc8.Length] != '\u001b' && text[i + Esc8.Length] != '\u0007';
                sb.Append(text, i, end - i);
                i = end;
            }
            sb.Append(mark).Append(Esc).Append("0m");
            if (linkOpen) sb.Append(LinkEnd);
            return new Line { Text = sb.ToString(), Plain = cut };
        }

        private const string Esc8 = "\u001b]8;;";
        private const string LinkEnd = "\u001b]8;;\u001b\\";

        /// <summary>Text that a terminal with hyperlink support (OSC 8) opens at <paramref name="url"/>; other terminals show the text alone.</summary>
        public static string Hyperlink(string text, string url)
        {
            if (string.IsNullOrEmpty(url)) return text ?? string.Empty;
            return Esc8 + url + "\u001b\\" + text + LinkEnd;
        }

        /// <summary>The index after the escape sequence (CSI or OSC) that starts at <paramref name="start"/>.</summary>
        private static int SequenceEnd(string s, int start)
        {
            int i = start;
            if (i + 1 < s.Length && s[i + 1] == '[')
            {
                i += 2;
                while (i < s.Length && !(s[i] >= '@' && s[i] <= '~')) i++;
            }
            else if (i + 1 < s.Length && s[i + 1] == ']')
            {
                i += 2;
                while (i < s.Length && s[i] != '\u0007' && !(s[i] == '\u001b' && i + 1 < s.Length && s[i + 1] == '\\')) i++;
                if (i < s.Length && s[i] == '\u001b') i++;
            }
            return Math.Min(s.Length, i + 1); // past the sequence's final character (or a lone escape)
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

        private int CurrentHeight()
        {
            if (Height > 0) return Height;
            try
            {
                int h = Console.WindowHeight;
                return h > 0 ? h : 24;
            }
            catch (Exception)
            {
                return 24;
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
                ? N((int)t.TotalHours) + ":" + t.Minutes.ToString("00", CultureInfo.InvariantCulture) + ":" + t.Seconds.ToString("00", CultureInfo.InvariantCulture)
                : N(t.Minutes) + ":" + t.Seconds.ToString("00", CultureInfo.InvariantCulture);
        }

        /// <summary>0.4 s under ten seconds, then m:ss.</summary>
        private static string Short(TimeSpan t)
        {
            return t.TotalSeconds < 10 ? t.TotalSeconds.ToString("0.0", CultureInfo.InvariantCulture) + " s" : Time(t);
        }
    }
}
