using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

namespace Maester.Engine
{
    /// <summary>
    /// The sounds of the game, in the manner of the machines of the eighties: a jump, a second jump, a
    /// coin, a stomp, a hit, a streak that grew by ten, the finish, the end of a game, a heart that came
    /// back, the snap of a mouth that opens to lunge, a wall that breaks, and DC01 going down. No sound file ships with the
    /// module: every sound is a fraction of a second of square wave or noise, worked out in memory as
    /// 16-bit mono PCM at a quarter of full scale.
    ///
    /// The game asks for a sound (RequestTone) and GameAudio plays it. Between the two is all that a test
    /// sees: the names of the sounds that were asked for. A sound is asked for only while the game is on
    /// screen, not paused and not muted (the M key), and only the renderer of the console ever plays one.
    ///
    /// Playing must never fail the run, hold it up or hold up a frame. A thread of its own starts the
    /// sounds, from a queue of a few that drops what does not fit, and whatever goes wrong turns the sound
    /// off for the rest of the run. Windows plays from memory (PlaySound of winmm). macOS and Linux have no
    /// such call: there the sounds are written once to a new folder under the temporary path, which Close
    /// removes, and a player of the system (afplay, paplay or aplay) is started for each.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const int ToneJump = 0;
        private const int ToneDouble = 1;
        private const int ToneCoin = 2;
        private const int ToneStomp = 3;
        private const int ToneHit = 4;
        private const int ToneStreak = 5;
        private const int ToneFinish = 6;
        private const int ToneDeath = 7;
        private const int ToneHeart = 8;
        private const int ToneSnap = 9;
        private const int ToneBreak = 10;
        private const int ToneDown = 11;
        private const int ToneIntro = 12;
        private const int ToneRate = 22050;
        private const double ToneLevel = 0.25;
        private const int ToneLogMost = 256;
        private static readonly string[] ToneNames = { "Jump", "DoubleJump", "Coin", "Stomp", "Hit", "Streak", "Finish", "Death", "Heart", "Snap", "Break", "Down", "Intro" };
        // Which sound gives way to which where only one can be heard at a time: the higher number is heard.
        private static readonly int[] ToneRank = { 0, 0, 1, 1, 2, 2, 3, 3, 2, 0, 3, 3, 3 };
        private static readonly byte[][] ToneWaves = new byte[ToneNames.Length][];
        // The tune of the start, in sixteenths of 0.075 seconds: a pitch (0 for a rest) and how many
        // sixteenths it lasts. A thin lead over a soft bass, a C major fanfare that ends on its home note.
        private const double IntroSixteenth = 0.075;
        private static readonly double[][] IntroLead =
        {
            new[] { 392.00, 1 }, new[] { 523.25, 1 }, new[] { 659.25, 1 }, new[] { 783.99, 3 }, new[] { 659.25, 1 }, new[] { 783.99, 4 }, new[] { 0.0, 1 },
            new[] { 698.46, 1 }, new[] { 880.00, 1 }, new[] { 783.99, 1 }, new[] { 659.25, 1 }, new[] { 587.33, 2 }, new[] { 523.25, 6 }
        };
        private static readonly double[][] IntroBass =
        {
            new[] { 130.81, 3 }, new[] { 0.0, 1 }, new[] { 196.00, 2 }, new[] { 130.81, 6 },
            new[] { 174.61, 4 }, new[] { 196.00, 2 }, new[] { 130.81, 6 }
        };
        private static readonly object ToneGate = new object();

        private readonly List<int> _toneBuffer = new List<int>();
        private readonly List<string> _toneLog = new List<string>();
        private GameAudio _audio;
        private bool _gameMuted;

        /// <summary>The names of the sounds of the game. For tests.</summary>
        public static string[] GameSoundNames { get { return (string[])ToneNames.Clone(); } }

        /// <summary>
        /// A sound of the game as a WAV file in memory (16-bit mono PCM), or null for a name that is not
        /// one of them. For tests.
        /// </summary>
        public static byte[] GetGameSound(string name)
        {
            int tone = Array.IndexOf(ToneNames, name);
            return tone < 0 ? null : (byte[])ToneWave(tone).Clone();
        }

        /// <summary>The names of the sounds the game asked for since the last call, in order. For tests.</summary>
        public string[] TakeGameSounds()
        {
            lock (_gate)
            {
                var names = _toneLog.ToArray();
                _toneLog.Clear();
                return names;
            }
        }

        // ------------------------------------------------------------------ asking for a sound (callers hold _gate)

        /// <summary>Asks for the sounds of what happened in the game since the last step or key.</summary>
        private void PlayGameSounds()
        {
            if (_game == null) return;
            _game.TakeTones(_toneBuffer);
            foreach (int tone in _toneBuffer) RequestTone(tone);
            _toneBuffer.Clear();
        }

        /// <summary>
        /// A sound, if the game is on screen and is not muted. It is noted for tests, and played by the
        /// renderer of the console: this only puts it in a queue, and never waits for anything.
        /// </summary>
        private void RequestTone(int tone)
        {
            if (_gameMuted || !_gameShown) return;
            if (_toneLog.Count >= ToneLogMost) _toneLog.RemoveAt(0);
            _toneLog.Add(ToneNames[tone]);
            if (!_console) return;
            try
            {
                if (_audio == null) _audio = new GameAudio();
                _audio.Play(tone);
            }
            catch (Exception)
            {
                // No sound, then.
            }
        }

        /// <summary>Whether sounds are heard: not muted, and nothing went wrong with playing them.</summary>
        private bool GameSoundOn { get { return !_gameMuted && (_audio == null || !_audio.Off); } }

        // ------------------------------------------------------------------ the sounds themselves

        private static byte[] ToneWave(int tone)
        {
            lock (ToneGate)
            {
                if (ToneWaves[tone] == null) ToneWaves[tone] = Wave(Synthesize(tone));
                return ToneWaves[tone];
            }
        }

        private static int ToneMilliseconds(int tone)
        {
            return (ToneWave(tone).Length - 44) / 2 * 1000 / ToneRate;
        }

        /// <summary>
        /// A sound as samples between -1 and 1. A jump is a square wave that rises from 260 to 620 Hz, and
        /// the second jump one that rises higher; a coin is three quick high notes; a stomp is a click of
        /// noise and a low falling thump; a hit is noise that falls and dies away; a streak is three notes
        /// that rise; the finish is four, the last one long. The end of a game is four notes that go
        /// down, the last one sinking away; a heart is three notes that leap up, an octave and a fifth;
        /// a snap is two short clicks of noise. A wall that breaks is a crack, a click of high noise, and
        /// after a moment a crumble: noise that falls and dies away over a low thump. DC01 going down is
        /// a machine that loses its power: a note that sinks four octaves, and a last crackle of noise.
        /// The start is a short fanfare of its own, a thin lead over a soft bass, that ends on its home note.
        /// </summary>
        private static List<double> Synthesize(int tone)
        {
            var wave = new List<double>();
            switch (tone)
            {
                case ToneJump:
                    AddSquare(wave, 260, 620, 0.12, 1, 0.5);
                    break;
                case ToneDouble:
                    AddSquare(wave, 420, 980, 0.11, 1, 0.5);
                    break;
                case ToneCoin:
                    AddSquare(wave, 880.0, 880.0, 0.04, 1, 0.9);
                    AddSquare(wave, 1108.73, 1108.73, 0.04, 1, 0.9);
                    AddSquare(wave, 1318.51, 1318.51, 0.1, 1, 0);
                    break;
                case ToneStomp:
                    AddNoise(wave, 3000, 1500, 0.03, 1, 0.6);
                    AddSquare(wave, 300, 90, 0.13, 1, 0);
                    break;
                case ToneHit:
                    AddNoise(wave, 1200, 150, 0.32, 1, 0);
                    break;
                case ToneStreak:
                    AddSquare(wave, 783.99, 783.99, 0.05, 1, 0.9);
                    AddSquare(wave, 987.77, 987.77, 0.05, 1, 0.9);
                    AddSquare(wave, 1174.66, 1174.66, 0.12, 1, 0);
                    break;
                case ToneDeath:
                    AddSquare(wave, 440.0, 440.0, 0.09, 1, 0.9);
                    AddSquare(wave, 349.23, 349.23, 0.09, 1, 0.9);
                    AddSquare(wave, 261.63, 261.63, 0.09, 1, 0.9);
                    AddSquare(wave, 196.0, 98.0, 0.3, 1, 0);
                    break;
                case ToneHeart:
                    AddSquare(wave, 523.25, 523.25, 0.05, 1, 0.9);
                    AddSquare(wave, 1046.5, 1046.5, 0.05, 1, 0.9);
                    AddSquare(wave, 1567.98, 1567.98, 0.14, 1, 0);
                    break;
                case ToneSnap:
                    AddNoise(wave, 2600, 2000, 0.025, 1, 0.7);
                    AddSquare(wave, 0, 0, 0.03, 0, 0);
                    AddNoise(wave, 2200, 900, 0.045, 1, 0);
                    break;
                case ToneDown:
                    AddSquare(wave, 660, 41, 0.55, 1, 0.5);
                    AddNoise(wave, 700, 90, 0.25, 0.7, 0);
                    break;
                case ToneIntro:
                    // The lead and the bass sound together, each at a part of the whole. Every note is
                    // struck and dies away a little; the last one dies away to nothing.
                    var bass = new List<double>();
                    for (int n = 0; n < IntroLead.Length; n++)
                    {
                        bool end = n == IntroLead.Length - 1;
                        double seconds = IntroLead[n][1] * IntroSixteenth;
                        if (IntroLead[n][0] <= 0) AddSquare(wave, 0, 0, seconds, 0, 0);
                        else AddPulse(wave, IntroLead[n][0], seconds, 0.6, end ? 0 : 0.35, 0.25);
                    }
                    foreach (var note in IntroBass)
                    {
                        double seconds = note[1] * IntroSixteenth;
                        if (note[0] <= 0) AddSquare(bass, 0, 0, seconds, 0, 0);
                        else AddSquare(bass, note[0], note[0], seconds, 0.4, 0.15);
                    }
                    for (int i = 0; i < bass.Count && i < wave.Count; i++) wave[i] += bass[i];
                    break;
                case ToneBreak:
                    AddNoise(wave, 5000, 2600, 0.035, 1, 0.5);
                    AddSquare(wave, 0, 0, 0.06, 0, 0);
                    // The crumble and the thump under it sound together: each at a part of the whole.
                    int from = wave.Count;
                    AddNoise(wave, 1100, 180, 0.5, 0.6, 0);
                    var thump = new List<double>();
                    AddSquare(thump, 110, 48, 0.3, 0.4, 0);
                    for (int i = 0; i < thump.Count; i++) wave[from + i] += thump[i];
                    break;
                default:
                    AddSquare(wave, 523.25, 523.25, 0.1, 1, 0.8);
                    AddSquare(wave, 659.25, 659.25, 0.1, 1, 0.8);
                    AddSquare(wave, 783.99, 783.99, 0.1, 1, 0.8);
                    AddSquare(wave, 1046.5, 1046.5, 0.3, 1, 0);
                    break;
            }
            return wave;
        }

        /// <summary>A square wave whose pitch and loudness go evenly from one value to another.</summary>
        private static void AddSquare(List<double> wave, double fromHz, double toHz, double seconds, double fromLevel, double toLevel)
        {
            int count = (int)(seconds * ToneRate);
            double phase = 0;
            for (int i = 0; i < count; i++)
            {
                double t = (double)i / count;
                phase += (fromHz + (toHz - fromHz) * t) / ToneRate;
                wave.Add((phase - Math.Floor(phase) < 0.5 ? 1 : -1) * (fromLevel + (toLevel - fromLevel) * t));
            }
        }

        /// <summary>
        /// A pulse wave: high for a part of each cycle (a quarter is the thin sound of old game consoles),
        /// at one pitch, with a loudness that goes evenly from one value to another.
        /// </summary>
        private static void AddPulse(List<double> wave, double hz, double seconds, double fromLevel, double toLevel, double duty)
        {
            int count = (int)(seconds * ToneRate);
            double phase = 0;
            for (int i = 0; i < count; i++)
            {
                double t = (double)i / count;
                phase += hz / ToneRate;
                wave.Add((phase - Math.Floor(phase) < duty ? 1 : -1) * (fromLevel + (toLevel - fromLevel) * t));
            }
        }

        /// <summary>
        /// Noise: a level that is thrown again, high or low, so many times a second, which gives the
        /// noise its pitch. The dice start from the same number each time: a sound is the same every time.
        /// </summary>
        private static void AddNoise(List<double> wave, double fromHz, double toHz, double seconds, double fromLevel, double toLevel)
        {
            int count = (int)(seconds * ToneRate);
            uint dice = 0x9E3779B9;
            double due = 1;
            double value = 0;
            for (int i = 0; i < count; i++)
            {
                double t = (double)i / count;
                due += (fromHz + (toHz - fromHz) * t) / ToneRate;
                if (due >= 1)
                {
                    due -= Math.Floor(due);
                    dice ^= dice << 13;
                    dice ^= dice >> 17;
                    dice ^= dice << 5;
                    value = (dice & 1) == 0 ? -1 : 1;
                }
                wave.Add(value * (fromLevel + (toLevel - fromLevel) * t));
            }
        }

        /// <summary>
        /// The samples as a WAV file: the 44 bytes of the header of 16-bit mono PCM, then the samples at
        /// a quarter of full scale, with two milliseconds at each end in which the sound comes and goes,
        /// so that it does not click.
        /// </summary>
        private static byte[] Wave(List<double> wave)
        {
            int count = wave.Count;
            int fade = ToneRate / 500;
            var bytes = new byte[44 + count * 2];
            PutText(bytes, 0, "RIFF");
            PutNumber(bytes, 4, 36 + count * 2, 4);
            PutText(bytes, 8, "WAVE");
            PutText(bytes, 12, "fmt ");
            PutNumber(bytes, 16, 16, 4);
            PutNumber(bytes, 20, 1, 2);
            PutNumber(bytes, 22, 1, 2);
            PutNumber(bytes, 24, ToneRate, 4);
            PutNumber(bytes, 28, ToneRate * 2, 4);
            PutNumber(bytes, 32, 2, 2);
            PutNumber(bytes, 34, 16, 2);
            PutText(bytes, 36, "data");
            PutNumber(bytes, 40, count * 2, 4);
            for (int i = 0; i < count; i++)
            {
                double edge = Math.Min(1.0, (double)Math.Min(i, count - 1 - i) / fade);
                PutNumber(bytes, 44 + i * 2, (int)Math.Round(wave[i] * edge * ToneLevel * short.MaxValue) & 0xFFFF, 2);
            }
            return bytes;
        }

        private static void PutText(byte[] bytes, int at, string text)
        {
            for (int i = 0; i < text.Length; i++) bytes[at + i] = (byte)text[i];
        }

        /// <summary>A number in <paramref name="size"/> bytes, the lowest first.</summary>
        private static void PutNumber(byte[] bytes, int at, int value, int size)
        {
            for (int i = 0; i < size; i++) bytes[at + i] = (byte)(value >> (8 * i));
        }

        // ------------------------------------------------------------------ playing

        /// <summary>
        /// Plays the sounds, on a thread of its own. Play only puts a sound in the queue. The thread makes
        /// ready when the first sound is asked for (the buffers, and on macOS and Linux the files and the
        /// player), then starts each sound. A sound that finds the queue full, or too many players still
        /// at it, is dropped: a sound that is late is worth nothing.
        /// </summary>
        private sealed class GameAudio
        {
            private const int QueueMost = 6;
            // A player of macOS is alive for most of a second, however short the sound: eight of them at most.
            private const int PlayersMost = 8;
            // The same sound is not started again sooner than this: coins that are close together are heard as a few.
            private const int SameGapMs = 100;
            private const int FailuresMost = 3;
            private const uint SoundAsync = 0x0001;
            private const uint SoundNoDefault = 0x0002;
            private const uint SoundMemory = 0x0004;

            private readonly object _lock = new object();
            private readonly Queue<int> _queue = new Queue<int>();
            private readonly List<Process> _players = new List<Process>();
            private readonly Stopwatch _clock = Stopwatch.StartNew();
            private readonly bool _windows = Environment.OSVersion.Platform == PlatformID.Win32NT;
            private Thread _worker;
            private bool _closed;
            private volatile bool _off;
            private string _folder;
            private string[] _files;
            private string _player;
            private string _playerOption;
            private GCHandle[] _pins;
            private readonly long[] _startedAt = new long[ToneNames.Length];
            private long _heardUntil;
            private int _heardRank;
            // What happened, for whoever checks it on a real console: the sounds that were started and
            // dropped, the most players at one time, how they ended, and how long the starts took.
            private int _started;
            private int _dropped;
            private int _most;
            private int _ended;
            private int _failed;
            private long _startTicks;
            private long _longestStartTicks;

            [DllImport("winmm.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            private static extern bool PlaySound(IntPtr sound, IntPtr module, uint flags);

            /// <summary>Nothing is played any more: there is nothing to play with, or playing failed.</summary>
            public bool Off { get { return _off; } }

            /// <summary>Puts a sound in the queue, when there is room. It never waits.</summary>
            public void Play(int tone)
            {
                if (_off) return;
                lock (_lock)
                {
                    if (_closed) return;
                    long now = _clock.ElapsedMilliseconds;
                    bool early = _startedAt[tone] != 0 && now - _startedAt[tone] < SameGapMs;
                    if (early || _queue.Count >= QueueMost)
                    {
                        _dropped++;
                        return;
                    }
                    _startedAt[tone] = now + 1;
                    _queue.Enqueue(tone);
                    if (_worker == null)
                    {
                        _worker = new Thread(Work) { IsBackground = true, Name = "Maester tones" };
                        _worker.Start();
                    }
                    Monitor.Pulse(_lock);
                }
            }

            /// <summary>No more sounds: the thread ends, the players are stopped and the files are removed.</summary>
            public void Close()
            {
                Thread worker;
                lock (_lock)
                {
                    _closed = true;
                    _queue.Clear();
                    worker = _worker;
                    Monitor.PulseAll(_lock);
                }
                // The thread is at most starting one player, which takes milliseconds. It is not waited for longer.
                try { if (worker != null) worker.Join(250); }
                catch (Exception) { /* It ends by itself. */ }
                Release();
            }

            /// <summary>
            /// Stops what plays and removes what was made: the players, the folder of the files, the
            /// buffers that Windows plays from. It takes no lock, so that a process that is ending can
            /// call it, and it can be called more than once.
            /// </summary>
            public void Release()
            {
                _off = true;
                try
                {
                    foreach (var player in _players.ToArray())
                    {
                        try { if (!player.HasExited) player.Kill(); }
                        catch (Exception) { /* It ended in the meantime. */ }
                        player.Dispose();
                    }
                    _players.Clear();
                }
                catch (Exception) { /* The thread was still at the list: the players end by themselves in under a second. */ }
                try
                {
                    string folder = _folder;
                    _folder = null;
                    if (folder != null && Directory.Exists(folder)) Directory.Delete(folder, true);
                }
                catch (Exception) { /* A folder of a few small files stays behind in the temporary path. */ }
                var pins = _pins;
                _pins = null;
                if (pins == null) return;
                // Windows may still be playing from a buffer: it is told to stop before the buffer is let go.
                try { PlaySound(IntPtr.Zero, IntPtr.Zero, 0); }
                catch (Exception) { /* It never played, then. */ }
                foreach (var pin in pins)
                {
                    if (pin.IsAllocated) pin.Free();
                }
            }

            /// <summary>What happened, for whoever checks it on a real console.</summary>
            public override string ToString()
            {
                double ticks = Stopwatch.Frequency / 1000.0;
                return "started=" + _started + " dropped=" + _dropped + " most=" + _most + " ended=" + _ended + " failed=" + _failed + " alive=" + _players.Count +
                    " startMs=" + (_started > 0 ? _startTicks / ticks / _started : 0).ToString("0.0", System.Globalization.CultureInfo.InvariantCulture) +
                    " longestStartMs=" + (_longestStartTicks / ticks).ToString("0.0", System.Globalization.CultureInfo.InvariantCulture) +
                    " off=" + _off + " player=" + (_windows ? "PlaySound" : _player) + " folder=" + _folder;
            }

            private void Work()
            {
                try
                {
                    Prepare();
                    while (!_off)
                    {
                        int tone;
                        lock (_lock)
                        {
                            while (_queue.Count == 0 && !_closed) Monitor.Wait(_lock);
                            if (_closed) break;
                            tone = _queue.Dequeue();
                        }
                        Start(tone);
                    }
                }
                catch (Exception)
                {
                    // No player, no sound device, a temporary path that cannot be written: silence.
                    _off = true;
                }
                finally
                {
                    bool closed;
                    lock (_lock) closed = _closed;
                    // Close may have given up waiting for this thread: what was made after that is removed here.
                    if (closed) Release();
                }
            }

            private static bool HasValue(string variable)
            {
                return !string.IsNullOrEmpty(Environment.GetEnvironmentVariable(variable));
            }

            /// <summary>A program on the PATH, or null.</summary>
            private static string OnPath(string name)
            {
                foreach (string folder in (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(Path.PathSeparator))
                {
                    if (folder.Length == 0) continue;
                    string path = Path.Combine(folder, name);
                    if (File.Exists(path)) return path;
                }
                return null;
            }

            /// <summary>Makes ready what the sounds are played with. Without anything to play with, the sound is off.</summary>
            private void Prepare()
            {
                // In a remote session the sound would come out of a computer that nobody sits at.
                if (HasValue("SSH_CONNECTION") || HasValue("SSH_CLIENT") || HasValue("SSH_TTY"))
                {
                    _off = true;
                    return;
                }
                if (_windows)
                {
                    // PlaySound plays from the buffer after it returned: the buffers stay where they are until Release.
                    var pins = new GCHandle[ToneNames.Length];
                    for (int i = 0; i < pins.Length; i++) pins[i] = GCHandle.Alloc(ToneWave(i), GCHandleType.Pinned);
                    _pins = pins;
                    return;
                }
                if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
                {
                    if (File.Exists("/usr/bin/afplay")) _player = "/usr/bin/afplay";
                }
                else
                {
                    _player = OnPath("paplay");
                    if (_player == null)
                    {
                        _player = OnPath("aplay");
                        _playerOption = "-q";
                    }
                }
                if (_player == null)
                {
                    _off = true;
                    return;
                }
                // The players read files: the sounds are written once, to a folder of their own that only this user can read.
                string folder = Directory.CreateTempSubdirectory("maester-").FullName;
                _folder = folder;
                var files = new string[ToneNames.Length];
                for (int i = 0; i < files.Length; i++)
                {
                    files[i] = Path.Combine(folder, ToneNames[i].ToLowerInvariant() + ".wav");
                    File.WriteAllBytes(files[i], ToneWave(i));
                }
                _files = files;
            }

            private void Start(int tone)
            {
                if (_windows)
                {
                    // PlaySound has one voice: a sound cuts the one before it short. A sound that matters
                    // less than the one that is heard waits its turn, which is to say it is dropped.
                    long now = _clock.ElapsedMilliseconds;
                    if (now < _heardUntil && ToneRank[tone] < _heardRank)
                    {
                        _dropped++;
                        return;
                    }
                    if (!PlaySound(_pins[tone].AddrOfPinnedObject(), IntPtr.Zero, SoundMemory | SoundAsync | SoundNoDefault))
                    {
                        _off = true;
                        return;
                    }
                    _heardUntil = now + ToneMilliseconds(tone);
                    _heardRank = ToneRank[tone];
                    _started++;
                    return;
                }
                Reap();
                if (_off) return;
                if (_players.Count >= PlayersMost)
                {
                    _dropped++;
                    return;
                }
                // All three streams are redirected: a child that inherits one of them counts as a user of
                // the terminal, and .NET then sets the terminal back to echo and line input while it runs.
                var info = new ProcessStartInfo(_player)
                {
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                if (_playerOption != null) info.ArgumentList.Add(_playerOption);
                info.ArgumentList.Add(_files[tone]);
                long before = _clock.ElapsedTicks;
                var player = Process.Start(info);
                long took = _clock.ElapsedTicks - before;
                _startTicks += took;
                _longestStartTicks = Math.Max(_longestStartTicks, took);
                if (player == null) return;
                player.StandardInput.Close();
                _players.Add(player);
                _started++;
                _most = Math.Max(_most, _players.Count);
            }

            /// <summary>Lets go of the players that are done. A player that keeps failing has nothing to play to: the sound is off.</summary>
            private void Reap()
            {
                for (int i = _players.Count - 1; i >= 0; i--)
                {
                    var player = _players[i];
                    if (!player.HasExited) continue;
                    if (player.ExitCode == 0) _ended++;
                    else if (++_failed >= FailuresMost) _off = true;
                    player.Dispose();
                    _players.RemoveAt(i);
                }
            }
        }
    }
}
