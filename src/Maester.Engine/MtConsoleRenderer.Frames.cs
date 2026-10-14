using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading;

namespace Maester.Engine
{
    /// <summary>
    /// How the frames went while the keys of the dashboard had the screen: how many there were, the
    /// longest time from one to the next, and what the longest frame waited for and took. Numbers only,
    /// for a line of debug output after the run.
    /// </summary>
    public sealed class MtConsoleFrameTiming
    {
        /// <summary>The frames that were drawn on the tick.</summary>
        public int Frames { get; set; }

        /// <summary>The longest time from the end of one frame to the end of the next, in milliseconds.</summary>
        public int LongestGapMs { get; set; }

        /// <summary>How many of those times were longer than 150 milliseconds.</summary>
        public int LongGaps { get; set; }

        /// <summary>How much of the run was done when the longest one was, in percent.</summary>
        public int WorstAtPercent { get; set; }

        /// <summary>The longest a tick came after it was due, in milliseconds.</summary>
        public int LongestLateMs { get; set; }

        /// <summary>The longest a tick waited for the keys of the console and for the renderer, in milliseconds.</summary>
        public int LongestWaitMs { get; set; }

        /// <summary>The longest a frame took to be worked out, in milliseconds.</summary>
        public int LongestBuildMs { get; set; }

        /// <summary>The longest the console took to take a frame, in milliseconds.</summary>
        public int LongestWriteMs { get; set; }

        /// <summary>The characters of all those frames together.</summary>
        public long Characters { get; set; }
    }

    /// <summary>
    /// The ticks of the dashboard, from a thread of its own. A timer of the runtime calls back on the
    /// thread pool, and a run uses that pool: when all its threads are held by work that waits (requests
    /// to a service, name lookups), a tick waits with them, for a second and more, and the screen stands
    /// still. A thread that does nothing else is never in that queue.
    ///
    /// One tick at a time: a tick that takes longer than the time between two of them is followed by the
    /// next after a short rest, in which whoever waits for the renderer gets it. Ticks that were missed
    /// are not made up for.
    /// </summary>
    internal sealed class MtConsoleTicker : IDisposable
    {
        private const int RestMs = 10;

        private readonly Action<long> _tick;
        private readonly AutoResetEvent _wake = new AutoResetEvent(false);
        private volatile int _interval;
        private volatile bool _stop;

        /// <summary>Starts the ticks: <paramref name="tick"/> is given the moment the tick was due, by the stopwatch.</summary>
        public MtConsoleTicker(Action<long> tick, int intervalMs)
        {
            _tick = tick;
            _interval = Math.Max(1, intervalMs);
            var thread = new Thread(Run) { IsBackground = true, Name = "Maester console" };
            thread.Start();
        }

        /// <summary>Another time between two ticks, from now on.</summary>
        public void Change(int intervalMs)
        {
            _interval = Math.Max(1, intervalMs);
            Wake();
        }

        /// <summary>No more ticks. One that is running ends on its own: nothing waits for it.</summary>
        public void Dispose()
        {
            _stop = true;
            Wake();
        }

        private void Wake()
        {
            try { _wake.Set(); }
            catch (ObjectDisposedException) { /* The thread is gone already. */ }
        }

        private void Run()
        {
            try
            {
                long frequency = Stopwatch.Frequency;
                long due = Stopwatch.GetTimestamp() + _interval * frequency / 1000;
                while (!_stop)
                {
                    long wait = (due - Stopwatch.GetTimestamp()) * 1000 / frequency;
                    if (wait > 0 && _wake.WaitOne((int)Math.Min(wait, int.MaxValue)))
                    {
                        // Woken: the end, or another time between two ticks, which counts from now.
                        due = Stopwatch.GetTimestamp() + _interval * frequency / 1000;
                        continue;
                    }
                    if (_stop) break;
                    try { _tick(due); }
                    catch (Exception) { /* A tick that fails must not end the ticks, or the process. */ }
                    long now = Stopwatch.GetTimestamp();
                    due = Math.Max(due + _interval * frequency / 1000, now + Math.Min(RestMs, _interval) * frequency / 1000);
                }
            }
            finally
            {
                _wake.Dispose();
            }
        }
    }

    public sealed partial class MtConsoleRenderer
    {
        private const int FrameLongGapMs = 150;
        // A frame of the tick has what changed: the lines of the dashboard that are not what the screen
        // has, and of the playfield of the game the cells. Besides that it has a line or two of the
        // screen as a whole, the next ones each time, so that whatever else got on the screen is gone
        // within two or three seconds. (Not the whole screen every so often: that frame is many times
        // the size of the others, and a console that is slow to take it stands still for it.)
        private const int FrameLinesAgain = 2;
        private const int FrameLinesAgainGame = 1;
        // Cells that did not change between two that did are written with them when they are this few:
        // that is shorter than moving the cursor over them.
        private const int FrameSkipLeast = 4;

        // The ticks of the dashboard that owns the screen. The two lines of the compact layout keep the timer.
        private MtConsoleTicker _ticker;

        // The console is written to one writer at a time. A frame that the tick worked out is written
        // after the renderer is left, so that a console that takes it slowly holds up nothing of the
        // run: whoever writes takes this lock, inside the lock of the renderer or without it, never the
        // other way round. Each write has a number, and a frame is written only when nothing was
        // written since it was worked out.
        private readonly object _writeGate = new object();
        private long _writeSerial;

        // What is on the screen when the last thing written was a frame of the tick: its lines, and the
        // cells of the playfield of the game. Null after anything else was written.
        private string[] _shownLines;
        private char[] _shownCells = new char[0];
        private byte[] _shownStyles = new byte[0];
        private bool[] _shownBehind = new bool[0];
        private int _shownTop;
        private int _shownRows;
        private int _shownWidth;
        private int _shownHeight;
        // The first of the lines that the next frame has as a whole.
        private int _shownAgain;
        // The line of the first row of the playfield in the screen that was built last, or -1 when that
        // screen has no playfield of its own (the dashboard, the wall).
        private int _canvasTop = -1;

        private int _frames;
        private long _frameLast = -1;
        private int _frameLongest;
        private int _frameLong;
        private int _frameWorstAt;
        private int _frameLate;
        private int _frameWait;
        private int _frameBuild;
        private int _frameWrite;
        private long _frameCharacters;

        /// <summary>How the frames went while the keys had the screen in this run, or null when they never had it.</summary>
        public MtConsoleFrameTiming GameFrameTiming
        {
            get
            {
                lock (_writeGate)
                {
                    if (_frames == 0) return null;
                    return new MtConsoleFrameTiming
                    {
                        Frames = _frames, LongestGapMs = _frameLongest, LongGaps = _frameLong, WorstAtPercent = _frameWorstAt,
                        LongestLateMs = _frameLate, LongestWaitMs = _frameWait, LongestBuildMs = _frameBuild, LongestWriteMs = _frameWrite,
                        Characters = _frameCharacters
                    };
                }
            }
        }

        /// <summary>A tick, as the thread of the dashboard makes it. For tests, which run without that thread.</summary>
        public void Tick()
        {
            OnTimer(Stopwatch.GetTimestamp());
        }

        /// <summary>
        /// The frame of the dashboard or of the game for the tick, as the text to write: the whole
        /// screen, or, when the last thing on the screen was such a frame of the same size, what
        /// changed since and a line or two as a whole. The caller holds the gate.
        /// </summary>
        private string BuildTickFrame()
        {
            int width = CurrentWidth();
            int height = CurrentHeight();
            _canvasTop = -1;
            var lines = BuildScreen(width, height, Ansi);
            var canvas = _gameCanvas;
            int top = _canvasTop;
            int rows = top >= 0 ? canvas.Height : 0;
            int cells = rows * canvas.Width;
            var sb = new StringBuilder(2048);
            sb.Append(Esc).Append("?2026h");
            bool whole = _shownLines == null || lines.Count == 0 || _shownLines.Length != lines.Count || _shownWidth != width || _shownHeight != height ||
                _shownTop != top || _shownRows != rows || (rows > 0 && _shownCells.Length != cells);
            if (whole)
            {
                sb.Append(Esc).Append('H');
                for (int i = 0; i < lines.Count; i++)
                {
                    sb.Append(lines[i].Text).Append(Esc).Append('K');
                    if (i < lines.Count - 1) sb.Append("\r\n");
                }
                sb.Append(Esc).Append('J');
                _shownAgain = 0;
            }
            else
            {
                int again = Math.Min(lines.Count, rows > 0 ? FrameLinesAgainGame : FrameLinesAgain);
                if (_shownAgain >= lines.Count) _shownAgain = 0;
                for (int i = 0; i < lines.Count; i++)
                {
                    if (!InTurn(i, _shownAgain, again, lines.Count))
                    {
                        if (i >= top && i < top + rows) continue;
                        if (string.Equals(lines[i].Text, _shownLines[i], StringComparison.Ordinal)) continue;
                    }
                    sb.Append(Esc).Append(N(i + 1)).Append(";1H").Append(lines[i].Text).Append(Esc).Append('K');
                    // Under the last line there is nothing.
                    if (i == lines.Count - 1) sb.Append(Esc).Append('J');
                }
                if (rows > 0) AppendChangedCells(sb, canvas, top, _shownAgain, again, lines.Count);
                _shownAgain = (_shownAgain + again) % lines.Count;
            }
            sb.Append(Esc).Append("?2026l");
            if (TaskbarProgress && _running)
            {
                int pct = _total > 0 ? (int)Math.Min(100L, 100L * FinishedCount() / _total) : 0;
                if (pct != _lastPercent)
                {
                    sb.Append("\u001b]9;4;1;").Append(N(pct)).Append('\u0007');
                    _lastPercent = pct;
                }
            }
            // This is what the screen has when the frame is written.
            if (_shownLines == null || _shownLines.Length != lines.Count) _shownLines = new string[lines.Count];
            for (int i = 0; i < lines.Count; i++) _shownLines[i] = lines[i].Text;
            if (rows > 0)
            {
                if (_shownCells.Length != cells)
                {
                    _shownCells = new char[cells];
                    _shownStyles = new byte[cells];
                    _shownBehind = new bool[cells];
                }
                Array.Copy(canvas.Cells, _shownCells, cells);
                Array.Copy(canvas.Styles, _shownStyles, cells);
                Array.Copy(canvas.Behind, _shownBehind, cells);
            }
            _shownTop = top;
            _shownRows = rows;
            _shownWidth = width;
            _shownHeight = height;
            return sb.ToString();
        }

        /// <summary>
        /// The cells of the playfield that are not what the screen has, run by run: the cursor is put
        /// where a run starts, and the run is written with its colours.
        /// </summary>
        private void AppendChangedCells(StringBuilder sb, Canvas canvas, int top, int againFrom, int again, int lines)
        {
            bool ansi = Ansi;
            int width = canvas.Width;
            byte style = GsNone;
            bool behind = false;
            bool pen = false;
            for (int y = 0; y < canvas.Height; y++)
            {
                // This frame has the line as a whole already.
                if (InTurn(top + y, againFrom, again, lines)) continue;
                int row = y * width;
                int x = 0;
                while (x < width)
                {
                    if (SameCell(canvas, row + x, ansi))
                    {
                        x++;
                        continue;
                    }
                    // The run goes on over a few cells that did not change, to the next one that did.
                    int last = x;
                    for (int scan = x + 1; scan < width && scan - last <= FrameSkipLeast; scan++)
                    {
                        if (!SameCell(canvas, row + scan, ansi)) last = scan;
                    }
                    sb.Append(Esc).Append(N(top + y + 1)).Append(';').Append(N(x + 1)).Append('H');
                    if (ansi && !pen)
                    {
                        // Whatever was written before this left its colours behind.
                        sb.Append(Esc).Append("0m");
                        pen = true;
                    }
                    for (; x <= last; x++)
                    {
                        char c = canvas.Cells[row + x];
                        if (ansi)
                        {
                            // A space has nothing to colour: it does not change the style.
                            byte want = c == ' ' ? style : canvas.Styles[row + x];
                            bool back = canvas.Behind[row + x];
                            if (want != style || back != behind)
                            {
                                sb.Append(Esc).Append('0');
                                if (want != GsNone) sb.Append(';').Append(GameSgr[want]);
                                if (back) sb.Append(';').Append(GameSkyline);
                                sb.Append('m');
                                style = want;
                                behind = back;
                            }
                        }
                        sb.Append(c);
                    }
                }
            }
            if (style != GsNone || behind) sb.Append(Esc).Append("0m");
        }

        /// <summary>Whether a line is one of the <paramref name="again"/> lines from <paramref name="from"/> on, round the end of the screen to its top.</summary>
        private static bool InTurn(int line, int from, int again, int lines)
        {
            int after = line - from;
            if (after < 0) after += lines;
            return after < again;
        }

        /// <summary>Whether a cell of the playfield is what the screen has: the same character, in the same colours.</summary>
        private bool SameCell(Canvas canvas, int i, bool ansi)
        {
            char c = canvas.Cells[i];
            if (c != _shownCells[i]) return false;
            if (!ansi) return true;
            if (canvas.Behind[i] != _shownBehind[i]) return false;
            return c == ' ' || canvas.Styles[i] == _shownStyles[i];
        }

        /// <summary>
        /// Writes a frame that the tick worked out, unless something else was written since: then the
        /// frame is of a screen that is gone. Called without the gate. True when it was written.
        /// </summary>
        private bool WriteFrame(string frame, long serial)
        {
            lock (_writeGate)
            {
                if (Interlocked.Read(ref _writeSerial) != serial) return false;
                try
                {
                    _writer.Write(frame);
                    _writer.Flush();
                }
                catch (Exception) { /* A console that cannot be written to must not fail the run. */ }
                return true;
            }
        }

        /// <summary>
        /// A frame of the game was written on the tick: when the tick was due, when it began, when it
        /// had the renderer, when the frame was worked out, and how much of the run was done. All but
        /// the last in ticks of the stopwatch.
        /// </summary>
        private void NoteFrame(long due, long began, long entered, long built, int percent, int characters)
        {
            long now = Stopwatch.GetTimestamp();
            lock (_writeGate)
            {
                _frames++;
                _frameCharacters += characters;
                _frameLate = Math.Max(_frameLate, Milliseconds(began - due));
                _frameWait = Math.Max(_frameWait, Milliseconds(entered - began));
                _frameBuild = Math.Max(_frameBuild, Milliseconds(built - entered));
                _frameWrite = Math.Max(_frameWrite, Milliseconds(now - built));
                if (_frameLast >= 0)
                {
                    int gap = Milliseconds(now - _frameLast);
                    if (gap > FrameLongGapMs) _frameLong++;
                    if (gap > _frameLongest)
                    {
                        _frameLongest = gap;
                        _frameWorstAt = percent;
                    }
                }
                _frameLast = now;
            }
        }

        /// <summary>The frames start again: the time since the last one is not a time between two frames.</summary>
        private void RestartFrames()
        {
            lock (_writeGate) _frameLast = -1;
        }

        private void ResetFrames()
        {
            lock (_writeGate)
            {
                _frames = 0;
                _frameLast = -1;
                _frameLongest = _frameLong = _frameWorstAt = _frameLate = _frameWait = _frameBuild = _frameWrite = 0;
                _frameCharacters = 0;
            }
        }

        private static int Milliseconds(long ticks)
        {
            if (ticks <= 0) return 0;
            return (int)Math.Min(int.MaxValue, ticks * 1000 / Stopwatch.Frequency);
        }
    }
}
