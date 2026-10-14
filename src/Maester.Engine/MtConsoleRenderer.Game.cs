using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace Maester.Engine
{
    /// <summary>
    /// How the best game of Maester Run of a run went: what the lines after the run say. Nothing in it is
    /// of the tenant.
    /// </summary>
    public sealed class MtConsoleGameResult
    {
        /// <summary>0 to 10,000: see Runner for how it is counted.</summary>
        public int Score { get; set; }

        /// <summary>The games of the run: more than one when a game was over and another was started.</summary>
        public int Games { get; set; }

        /// <summary>The run was long enough for DC01, the last one in the way, and whether that game decommissioned it.</summary>
        public bool Boss { get; set; }

        public bool BossDown { get; set; }

        /// <summary>The tests of the run, which the score is a share of.</summary>
        public int Tests { get; set; }

        /// <summary>Passed tests that were collected.</summary>
        public int Coins { get; set; }

        /// <summary>What was stomped: failed tests, and what the game put in the way itself.</summary>
        public int Stomps { get; set; }

        public int Hits { get; set; }
        public int BestStreak { get; set; }

        /// <summary>The best score of this user so far, with the day it was made (yyyy-MM-dd), or 0 and null.</summary>
        public int Best { get; set; }

        public string BestDate { get; set; }

        /// <summary>This game is the best so far, and was written down as that.</summary>
        public bool NewBest { get; set; }
    }

    /// <summary>
    /// Maester Run, the game behind the dashboard. Typing the word "dead" while tests run on the full-screen
    /// dashboard puts it on screen (the keys are in MtConsoleRenderer.Input.cs, the sounds in
    /// MtConsoleRenderer.Sound.cs, and how it breaks through the dashboard the first time, with its help,
    /// in MtConsoleRenderer.Wall.cs). A runner runs, the world scrolls past, and the course is the run itself:
    /// every result becomes something on it, in the order the results arrive. A passed test is a coin, a
    /// failed test is a creature to jump on, a test that ended in an error is a plant to jump over, and
    /// one to investigate is a bird. The dice add small things of their own where the run leaves room.
    /// One key plays it: jump, and again in the air for a second jump. The run goes on underneath: the
    /// first two rows show its real progress, and the game ends when the tests do. The runner has three
    /// hearts, and a game is over when the last is gone: another game can be started for what is left of
    /// the run.
    ///
    /// Runner is the game itself: a state machine that is moved by the time that passed (Step) and by its
    /// key (Jump), and that draws its playfield into a grid of cells. It knows nothing of the console or
    /// of the run. The renderer feeds it the results and draws the rows around the playfield from its own
    /// counters.
    ///
    /// While the game is not on screen none of this runs. All that a run pays for it then is one entry in a
    /// list for each result, so that a game that starts in the middle of a run has what came before.
    /// </summary>
    public sealed partial class MtConsoleRenderer
    {
        private const int GameLeastWidth = 80;
        private const int GameLeastHeight = 24;
        // The rows of the screen that are not playfield: the HUD and the progress bar above it, the ticker and the keys under it.
        private const double GameLongestStep = 0.025;
        private const int GameFullScore = 10000;
        private const string GameOrange = "1;38;5;208";
        // The red of the Maester logo, the first colour of its wordmark: as it is, and the nearest of 256 colours.
        private const string GameRedTrue = "1;38;2;229;36;59";
        private const string GameRed = "1;38;5;197";
        // A result on the course: nothing, a passed test, a failed test of a severity (Critical, High,
        // Medium, Low, other), a test that ended in an error, or one to investigate.
        private const byte ResultOther = 0;
        private const byte ResultPassed = 1;
        private const byte ResultFailed = 2;
        private const int GameOtherSeverity = 4;
        private const byte ResultError = 7;
        private const byte ResultInvestigate = 8;

        // What is on the course. A walker and an attack are of the dice; a biter, a brute and a giant are
        // failed tests (Low and Medium, High, Critical); a plant is a test that ended in an error, or of
        // the dice; a bird is a test to investigate, or of the dice; a spring throws the runner up; a
        // packet is what DC01 throws along the ground.
        private const byte KindCoin = 0;
        private const byte KindWalker = 1;
        private const byte KindBiter = 2;
        private const byte KindBrute = 3;
        private const byte KindGiant = 4;
        private const byte KindPlant = 5;
        private const byte KindBird = 6;
        private const byte KindAttack = 7;
        private const byte KindSpring = 8;
        private const byte KindPacket = 9;
        private static readonly string[] GameKindNames = { "Coin", "Walker", "Biter", "Brute", "Giant", "Plant", "Bird", "Attack", "Spring", "Packet" };
        // The rows a thing is high, by its kind. A jump takes the runner up four and a half rows, so
        // the giant needs the second jump to get on top of.
        private static readonly int[] GameKindRows = { 2, 2, 2, 3, 5, 2, 2, 2, 1, 2 };
        private static readonly int[] GameKindWidth = { 2, 3, 5, 5, 7, 3, 5, 3, 8, 3 };
        // The score: all of it for the tests of a run that is too short for DC01, and otherwise nine
        // tenths for the tests and a tenth for DC01.
        private const int GameTestsScore = 9000;
        private const int GameBossScore = 1000;
        // DC01 comes when the tests that are left take no longer than this, or when nine tenths are done.
        private const double GameBossSeconds = 60;
        // And not at all in a run whose tests take less than this: that has no room for the fight and
        // for what waited while it went on.
        private const double GameBossRunSeconds = 120;
        // What is known of the run for DC01: nothing yet, or, from the moment it would be due, that the
        // run is too short for it, or that it is due.
        private const int GameBossShort = 1;
        private const int GameBossIsDue = 2;
        private const double GameWordsSeconds = 4;

        // The styles of the cells of the playfield, and the colour of each.
        private const byte GsNone = 0;
        private const byte GsBackdrop = 1;
        private const byte GsCaption = 2;
        private const byte GsCritical = 3;
        private const byte GsHigh = 4;
        private const byte GsMedium = 5;
        private const byte GsLow = 6;
        private const byte GsCoin = 7;
        private const byte GsLabel = 8;
        private const byte GsGround = 9;
        private const byte GsRunner = 10;
        private const byte GsPlatform = 11;
        private const byte GsScenery = 12;
        private const byte GsPoints = 13;
        private const byte GsDust = 14;
        private const byte GsCard = 15;
        private const byte GsCardTitle = 16;
        private const byte GsCardText = 17;
        private const byte GsCardDim = 18;
        private const byte GsWalker = 19;
        private const byte GsPlant = 20;
        private const byte GsPot = 21;
        private const byte GsBird = 22;
        private const byte GsError = 23;
        private const byte GsInvestigate = 24;
        private const byte GsHeart = 25;
        private const byte GsWall = 26;
        private const byte GsWallMark = 27;
        private const byte GsCoinName = 28;
        private const byte GsAttack = 29;
        private const byte GsBoss = 30;
        private const byte GsBossLight = 31;
        private const byte GsBossAlarm = 32;
        private const byte GsSpring = 33;
        private const byte GsRunnerTrue = 34;
        // The colour behind the cells of the far skyline: a shade of the dark of the screen.
        private const string GameSkyline = "48;5;235";
        private static readonly string[] GameSgr =
        {
            null, "38;5;236", "38;5;240", "1;35", "38;5;208", "33", "38;5;245", "1;33", "2", "38;5;242",
            GameRed, "38;5;65", "38;5;239", "1;33", "38;5;238", "38;5;208", GameOrange, "1", "2",
            "38;5;73", "38;5;71", "38;5;130", "38;5;110", "38;5;203", "36", "1;31", "3;38;5;252", "1;3;38;5;196",
            "2;32", "38;5;168", "38;5;111", "1;32", "1;31", "1;36", GameRedTrue
        };
        private static readonly byte[] GameSeverityStyle = { GsCritical, GsHigh, GsMedium, GsLow, GsLow };

        // The coin of one test as it turns, its face and its edge, and the coin of several tests.
        private static readonly string[][] GameCoin = { new[] { "▟▙", "▜▛" }, new[] { "▐▌", "▐▌" } };
        private static readonly string[][] GameCoinAscii = { new[] { "/\\", "\\/" }, new[] { "||", "||" } };
        private static readonly string[] GameCoins = { "▟█▙", "▜█▛" };
        private static readonly string[] GameCoinsAscii = { "/O\\", "\\O/" };

        // The creatures, each as it is drawn in turn while it walks. A biter and a brute have a third
        // way, with the mouth open, for when they lunge. The ones that are nine cells wide stand for
        // several tests.
        private static readonly string[][] GameWalker = { new[] { "▗█▖", "▛ ▜" }, new[] { "▗█▖", "▜ ▛" } };
        private static readonly string[][] GameWalkerAscii = { new[] { "(\")", "/ \\" }, new[] { "(\")", "| |" } };
        private static readonly string[][] GameBiter =
        {
            new[] { "▗▟▀█▙", "▝▜▛▀▘" }, new[] { "▗▟▀█▙", "▝▜▀▛▘" }, new[] { "▛▀▀█▙", "▙▄▛▀▘" }
        };
        private static readonly string[][] GameBiterAscii =
        {
            new[] { "=(oo)", " /\\/\\" }, new[] { "=(oo)", " \\/\\/" }, new[] { "\\(oo)", "//\\/\\" }
        };
        private static readonly string[][] GameBiters =
        {
            new[] { "▗▟▀█▀█▀█▙", "▝▜▛▀▘▛▀▘ " }, new[] { "▗▟▀█▀█▀█▙", "▝▜▀▛▘ ▛▀▘" }, new[] { "▛▀▀█▀█▀█▙", "▙▄▛▀▘▛▀▘ " }
        };
        private static readonly string[][] GameBitersAscii =
        {
            new[] { "=(oo-oo-)", " /\\/\\/\\/\\" }, new[] { "=(oo-oo-)", " \\/\\/\\/\\/" }, new[] { "\\(oo-oo-)", "//\\/\\/\\/\\" }
        };
        private static readonly string[][] GameBrute =
        {
            new[] { " ▟██▙", "▄█▀██", "▀█▛▜▛" }, new[] { " ▟██▙", "▄█▀██", "▀█▜▛▜" }, new[] { " ▟██▙", "▀█▀██", "▄█▛▜▛" }
        };
        private static readonly string[][] GameBruteAscii =
        {
            new[] { " .--.", "=|oo|", " /\\/\\" }, new[] { " .--.", "=|oo|", " \\/\\/" }, new[] { " .--.", "\\|oo|", "//\\/\\" }
        };
        private static readonly string[][] GameBrutes =
        {
            new[] { " ▟██████▙", "▄█▀██▀███", "▀█▛▜▛▜▛▜▛" }, new[] { " ▟██████▙", "▄█▀██▀███", "▀█▜▛▜▛▜▛▜" }, new[] { " ▟██████▙", "▀█▀██▀███", "▄█▛▜▛▜▛▜▛" }
        };
        private static readonly string[][] GameBrutesAscii =
        {
            new[] { " .------.", "=|oo  oo|", " /\\/\\/\\/\\" }, new[] { " .------.", "=|oo  oo|", " \\/\\/\\/\\/" }, new[] { " .------.", "\\|oo  oo|", "//\\/\\/\\/\\" }
        };
        private static readonly string[][] GameGiant =
        {
            new[] { "▙ ▟█▙ ▟", "▜█████▛", "█▀███▀█", "▜██▀██▛", " ▛▘ ▝▜ " }, new[] { "▙ ▟█▙ ▟", "▜█████▛", "█▀███▀█", "▜██▄██▛", " ▜▘ ▝▛ " }
        };
        private static readonly string[][] GameGiantAscii =
        {
            new[] { "\\ ^^^ /", "|-----|", "|O   O|", "|\\vvv/|", "/_\\ /_\\" }, new[] { "\\ ^^^ /", "|-----|", "|O   O|", "|/^^^\\|", "\\_/ \\_/" }
        };
        private static readonly string[][] GameGiants =
        {
            new[] { "▙ ▟█▙ ▟█▙", "▜███████▛", "█▀██▀██▀█", "▜██▀█▀██▛", " ▛▘ ▛▜ ▝▜" }, new[] { "▙ ▟█▙ ▟█▙", "▜███████▛", "█▀██▀██▀█", "▜██▄█▄██▛", " ▜▘ ▜▛ ▝▛" }
        };
        private static readonly string[][] GameGiantsAscii =
        {
            new[] { "\\ ^^^^^ /", "|-------|", "|O  O  O|", "|\\vvvvv/|", "/_\\ | /_\\" }, new[] { "\\ ^^^^^ /", "|-------|", "|O  O  O|", "|/^^^^^\\|", "\\_/ | \\_/" }
        };
        // An attack: hooded, on its feet. A spring. A packet that DC01 throws. And DC01 itself: a rack
        // with two lights, which are drawn over it in their own colour.
        private static readonly string[][] GameAttack = { new[] { "▟▀▙", "▛▄▜" }, new[] { "▟▀▙", "▜▄▛" } };
        private static readonly string[][] GameAttackAscii = { new[] { "/^\\", "/_\\" }, new[] { "/^\\", "|_|" } };
        private const string GameSpring = "▟▚▞▚▞▚▞▙";
        private const string GameSpringAscii = "/^^^^^^\\";
        private static readonly string[] GamePacket = { "▛▀▜", "▙▄▟" };
        private static readonly string[] GamePacketAscii = { "+-+", "+-+" };
        private static readonly string[] GameBoss = { "▛▀▀▀▀▀▀▀▜", "▌● ━━━━ ▐", "▌━━━━━━━▐", "▌● ━━━━ ▐", "▌▚▚▚▚▚▚▚▐", "▙▄▄▄▄▄▄▄▟" };
        private static readonly string[] GameBossAscii = { "+-------+", "|o ==== |", "|=======|", "|o ==== |", "|:::::::|", "+-------+" };
        // A plant: its pot alone, the plant as it comes up, and up with its mouth open and shut.
        private static readonly string[][] GamePlant =
        {
            new[] { "   ", "▜█▛" }, new[] { "▗▄▖", "▜█▛" }, new[] { "▚█▞", "▜█▛" }, new[] { "▐█▌", "▜█▛" }
        };
        private static readonly string[][] GamePlantAscii =
        {
            new[] { "   ", "\\_/" }, new[] { " . ", "\\_/" }, new[] { "\\V/", "\\_/" }, new[] { "(Y)", "\\_/" }
        };
        // A bird, its wings up and down, and what is left in the air of one that was stomped.
        private static readonly string[][] GameBird = { new[] { "▙   ▟", " ▜█▛ " }, new[] { " ▟█▙ ", "▛   ▜" } };
        private static readonly string[][] GameBirdAscii = { new[] { "\\   /", " \\v/ " }, new[] { " /^\\ ", "/   \\" } };
        // The runner: head, body, and the legs as it runs (two ways) and as it jumps; and the head it has while it stumbles.
        private static readonly string[] GameRunner = { " ▟█▙ ", "▐███▌", " ▛ ▜ ", " ▐ ▌ ", " ▘ ▝ ", " ▗▄▖ " };
        private static readonly string[] GameRunnerAscii = { " /^\\ ", "[###]", " / \\ ", " | | ", " ' ' ", " ._. " };
        private static readonly string[] GameCloud = { "  ▁▃▅▃▁", "▁▃█████▃▁" };
        private static readonly string[] GameCloudAscii = { "  .--.", " (____)" };

        // The names of what the dice put on the course, and of what DC01 throws. None of them is a test.
        // A walker has a habit that a tenant is better off without.
        private static readonly string[] GameHabits =
        {
            "NTLM", "SMBv1", "Basic auth", "password123", "temp-admin", "Shadow IT", "legacy auth", "macro.docm", "TODO", "GA x 40",
            "TLS 1.0", "admin/admin", "Any-Any rule", "shared login", "SMS codes", "POP3", "IMAP", "Telnet", "FTP", "stale guest",
            "test-user", "open RDP", "port 3389", "qwerty", "local admin", "LM hash", "WEP", "SSLv3", "MD5", "RC4",
            "sticky note", "old secret", "Summer2025!", "svc-admin", "allow all", "Everyone:Full", "self-signed", "default creds", "pwd in script", "one admin"
        };
        // An attack, on the ground.
        private static readonly string[] GameAttacks =
        {
            "ransomware", "phishing", "password spray", "MFA fatigue", "token theft", "AiTM", "BEC", "infostealer", "kerberoasting", "pass-the-hash",
            "DCSync", "golden ticket", "brute force", "cryptominer", "wiper", "botnet", "insider", "SIM swap", "consent phishing", "session hijack",
            "credential stuffing", "device code phish", "QR phishing", "supply chain", "lateral movement", "data exfil"
        };
        // A threat actor, in the sky: the names that Microsoft gives them are of the weather.
        private static readonly string[] GameActors =
        {
            "Midnight Blizzard", "Volt Typhoon", "Octo Tempest", "Mint Sandstorm", "Jade Sleet", "Storm-0558", "Forest Blizzard", "Silk Typhoon",
            "Salt Typhoon", "Flax Typhoon", "Diamond Sleet", "Peach Sandstorm", "Seashell Blizzard", "Cadet Blizzard", "Citrine Sleet", "Storm-1175"
        };
        // What DC01 throws: of Active Directory.
        private static readonly string[] GameDirectory =
        {
            "GPO", "krbtgt", "LDAP", "SYSVOL", "NTLM", "golden ticket", "NETLOGON", "FSMO", "ntds.dit", "AdminSDHolder",
            "SPN", "DSRM", "trust", "replication", "RID 500", "schema", "KDC", "GPP cpassword"
        };

        // The digits 0 to 9 and the slash, five cells wide and five high, row by row.
        private static readonly string[] GameDigits =
        {
            "######   ##   ##   ######", "  #   ##    #    #  #####", "#####    #######    #####", "#####    ######    ######",
            "#   ##   ######    #    #", "######    #####    ######", "######    ######   ######", "#####    #   #   #    #  ",
            "######   #######   ######", "######   ######    ######", "    #   #   #   #   #    "
        };

        /// <summary>A result of the run, as the game needs it: what it was, and for the ticker which test.</summary>
        private struct RunResult
        {
            public string Id;
            public string Title;
            public byte Kind;
        }

        /// <summary>A coin, a creature, a plant or a bird on the course.</summary>
        private sealed class Thing
        {
            public byte Kind;
            public double X;
            public int Width;
            public int Height;
            // The rows above the ground of its lowest row. A bird has it in Y, which is not a whole number.
            public int Base;
            public double Y;
            // The cells a second it comes towards the runner, on top of the world going by.
            public double Speed;
            public int Severity;
            // The results it stands for: one, several when results came faster than they can be played,
            // or none for what the dice put on the course.
            public int Count;
            public string Id;
            public string Title;
            // Its name is drawn over it: the ID of a test, or the name the dice gave it.
            public bool Named;
            // It stands for a test of the run. And: DC01 threw it.
            public bool Test;
            public bool Shot;
            // It was with the runner while the runner could not be hit: it is on its way past, and does not hit after that.
            public bool Through;
            // Where it is in what it does: a biter in its lunge, a plant in its going up and down, a bird that turned away.
            public byte State;
            public double Clock;
            public bool Gone;
            public double GoneFor;
        }

        /// <summary>
        /// A bridge: a stretch of floor above the ground, on one of the levels, which are four rows apart.
        /// An open one goes on to the edge of the screen until it is closed. One of the route is where the
        /// course puts the run; the others are room to move in.
        /// </summary>
        private sealed class Platform
        {
            public double From;
            public double To;
            public int Level;
            public int Surface;
            public bool Route;
            // The runner gets on it with a jump, from the level Low. And where it ends the runner comes down to the level Down.
            public bool Climb;
            public int Low;
            public int Down;
        }

        /// <summary>Points that rise from where they were earned, for a moment.</summary>
        private sealed class Popup
        {
            public double X;
            public double Y;
            public string Text;
            public double Age;
            public bool Heart;
        }

        /// <summary>The cells of the playfield for one frame: a character and a style each.</summary>
        private sealed class Canvas
        {
            public int Width;
            public int Height;
            public char[] Cells = new char[0];
            public byte[] Styles = new byte[0];
            // What is far behind the cell: nothing, or the skyline. It is a colour behind the cell, so
            // that what is drawn in the cell is in front of it and cuts no hole in it.
            public bool[] Behind = new bool[0];

            public void Reset(int width, int height)
            {
                if (width != Width || height != Height)
                {
                    Width = width;
                    Height = height;
                    Cells = new char[width * height];
                    Styles = new byte[width * height];
                    Behind = new bool[width * height];
                }
                for (int i = 0; i < Cells.Length; i++) Cells[i] = ' ';
                Array.Clear(Styles, 0, Styles.Length);
                Array.Clear(Behind, 0, Behind.Length);
            }

            public void Back(int x, int y)
            {
                if (x < 0 || y < 0 || x >= Width || y >= Height) return;
                Behind[y * Width + x] = true;
            }

            public void Put(int x, int y, char c, byte style)
            {
                if (x < 0 || y < 0 || x >= Width || y >= Height) return;
                Cells[y * Width + x] = c;
                Styles[y * Width + x] = style;
            }

            /// <summary>Text from a cell on. Its spaces are not drawn: what is under them shows.</summary>
            public void Text(int x, int y, string text, byte style)
            {
                for (int i = 0; i < text.Length; i++)
                {
                    if (text[i] != ' ') Put(x + i, y, text[i], style);
                }
            }

            /// <summary>Text behind what the canvas has: only its cells that are still empty are drawn.</summary>
            public void Under(int x, int y, string text, byte style)
            {
                if (y < 0 || y >= Height) return;
                for (int i = 0; i < text.Length; i++)
                {
                    int at = x + i;
                    if (text[i] != ' ' && at >= 0 && at < Width && Cells[y * Width + at] == ' ') Put(at, y, text[i], style);
                }
            }

            /// <summary>The same with the spaces drawn as well, which covers what is under the text.</summary>
            public void Cover(int x, int y, string text, byte style)
            {
                for (int i = 0; i < text.Length; i++) Put(x + i, y, text[i], style);
            }
        }

        /// <summary>
        /// The game. The world is measured in cells along the ground and in rows above it, and everything
        /// that moves has a speed in cells or rows a second: a step moves it by the time that passed, a
        /// fortieth of a second at a time, so that nothing passes through anything however long the step is.
        ///
        /// The course. The results wait in a queue and are put on the course at the right edge of the
        /// screen, where there is room: a passed test as a coin, a failed test as a creature that walks
        /// towards the runner. The course has a route, which is on the ground or on a bridge of one of
        /// the levels above it, four rows apart: two levels on a low screen, up to four on a tall one.
        /// What the run sends is put on the route, coins and creatures alike. The route goes up when four
        /// passed tests follow one another, and when the dice say so; a bridge has room for a few pieces,
        /// and then the route goes one level up, with a jump, or two, from a spring, or down again. The
        /// coin of a step up is in the air where the jump goes. When more wait than can be played one at
        /// a time (a burst of results, or all that came while the game was not on screen), one piece
        /// stands for several: a large coin for passed tests, a wide creature for failed ones, with the
        /// ID of the most severe.
        ///
        /// What is in the way. A failed test of low or medium severity is a biter: it walks, and when the
        /// runner is on its floor and near, it opens its mouth, for long enough to be answered, and
        /// lunges. One of high severity is a brute: a row taller and twice as fast. A critical one is the
        /// giant, which only the second jump gets on top of. All three are stomped by coming down on
        /// them. A test that ended in an error is a plant in a pot, with the ID of the test: it comes up
        /// and goes down again, it cannot be stomped, and it is jumped over while it is up. When it is
        /// down it is only its pot, which the runner runs past, and it does not come up while the runner
        /// is near. A test to investigate is a bird, with its ID: it flies at the height of the runner,
        /// hits from the side and from below, and is stomped from above.
        ///
        /// The dice add walkers (small, slow, with a habit for a name), attacks (hooded, a little
        /// faster), plants and birds with the names of threat actors, more of them the fewer failed tests
        /// the run sends; and bridges beside the route, which are room to move in. None of that is worth
        /// points or is in what the score is a share of; stomping counts for the streak.
        ///
        /// Nothing is put where it cannot be passed. For everything the runner has to do something about,
        /// the game works out when the runner will meet it, and keeps a second or so between two of them
        /// that are in each other's way: two things on the same floor, a bird and the jump over something
        /// under it, anything and the place where a bridge of the route starts or a bridge ends. Nothing
        /// is met under a bridge beside the route either, where the jump for it would come down on the
        /// bridge. Something that does not fit waits for room. What walks keeps that distance as the
        /// speed changes, and a bird that would come too close after all turns away, up into the sky,
        /// where it touches nothing. A coin is had from as high as any jump goes over it.
        ///
        /// DC01. A run of fifty tests or more, whose tests take two minutes or longer, has a last
        /// one in the way: when the run is near its end, the course stops and DC01 comes on screen, a
        /// rack that stays ahead of the runner. It throws things, along the ground and through the air,
        /// and now and then it charges: that is when it is stomped, with the second jump. Four stomps,
        /// and it is decommissioned: the course goes on with what is left of the run.
        ///
        /// The score is a share of 10,000. A passed test that is collected is worth a full test, a failed
        /// test that is stomped half of one. Six tenths of that are had at once; four tenths go with the
        /// form the runner is in, which is full at the start, gone after a hit, and back after ten
        /// pick-ups. In a run that has DC01 the tests are nine tenths of the score, and DC01 is a tenth,
        /// by the stomps it took. So a runner that collects every test of a run in which every test
        /// passes, is never hit, and decommissions DC01, has 10,000 exactly, whatever the number of
        /// tests; what failed or was missed is not earned. The tests that had not reached the runner
        /// when the tests stopped (they wait, or are still ahead on the course) are not in what the
        /// score is a share of, for a runner that was running to the last; and DC01 is not in it for a
        /// game whose screen it never came on.
        ///
        /// A hit takes a heart, of three. A streak of twenty-five gives one back. With the last heart the
        /// game is over.
        /// </summary>
        private sealed class Runner
        {
            private const int RunnerWidth = 5;
            private const int RunnerRows = 3;
            // A jump is 4.6 rows high and takes 0.65 seconds: 88 rows a second squared down, 28.5 rows a second up.
            private const double Gravity = 88;
            private const double JumpSpeed = 28.5;
            private const double BounceSpeed = 20;
            // A jump from a spring is 9.5 rows high: two levels.
            private const double SpringSpeed = 41;
            private const double BaseSpeed = 22;
            private const double SpeedPerStreak = 0.02;
            private const double SpeedMost = 0.6;
            private const double SpeedChange = 8;
            private const double HitSeconds = 1.5;
            // A key that is held comes again every 30 to 90 ms: a jump key that soon after the last one is not a second press.
            private const double RepeatSeconds = 0.11;
            // A jump key just before the runner lands is a jump when it has landed.
            private const double EarlySeconds = 0.12;
            private const double GoneSeconds = 0.45;
            private const double PopupSeconds = 0.7;
            private const int LevelRows = 4;
            // The rows above the surface of the highest level that the course needs: six for the giant
            // and its name, three for a bird that turned away and its name, and one between that and the sky.
            private const int SkyRows = 10;
            private const int LevelsMost = 4;
            private const int PlatformFrom = 4;
            private const int PlatformCoins = 6;
            private const int GroundCoins = 3;
            private const double PlatformHoldSeconds = 1.3;
            private const int CoinGap = 4;
            // A bridge that is reached from the ground starts this far before the first piece on it, so
            // that the runner is on it by then.
            private const int PlatformLead = 8;
            private const int PlatformAfter = 10;
            // A coin is collected from this many rows above it as well: a runner that jumps over a coin,
            // or bounces over it, or runs along a bridge above it, has it. More than the top of the
            // second jump and of the jump from a spring: no coin is missed for being jumped over.
            private const int CoinReach = 7;
            // Where one bridge follows another a level up: the new one starts this far after the last
            // piece of the old one would have been, the old one goes on for a few cells more, and the
            // first piece on the new one is well past the step.
            private const int StepFrom = 4;
            private const int StepOver = 4;
            private const int StepCoin = 18;
            // The coin of a step up is in the air where the jump goes: so far before the new bridge, and so high.
            private const int ArcBack = 5;
            private const int ArcRows = 3;
            // After a spring the next piece is where the runner has come down, two levels up.
            private const int SpringLand = 34;
            // More results than this waiting: one piece stands for several, an eighth of what waits.
            private const int GroupFrom = 6;
            private const int GroupPieces = 8;
            private const int FormFull = 10;
            private const int StreakMilestone = 10;
            public const int Hearts = 3;
            private const int HeartStreak = 25;
            // How long the runner takes to go down when the game is over, before the card.
            public const double OverSeconds = 0.7;

            private const double WalkerSpeed = 2;
            private const double AttackSpeed = 3.5;
            private const double BiterSpeed = 3;
            private const double BruteSpeed = 6;
            private const double GiantSpeed = 2;
            private const double BirdSpeed = 5;
            private const double PacketSpeed = 9;
            // A biter or a brute opens its mouth when the runner, on its floor, would be with it in this
            // many seconds at the speed of the world. The mouth is open for so long, which is the time
            // to answer it; then it lunges, so many cells a second for so long, and stands for a moment.
            private const double LungeAhead = 0.75;
            private const double LungeWait = 0.45;
            private const double LungeSeconds = 0.16;
            private const double BiterLunge = 30;
            private const double BruteLunge = 35;
            private const double LungeRest = 0.35;
            // The runner counts as on the floor for a lunge when it has been there this long.
            private const double SettleSeconds = 0.2;
            private const byte StateWalk = 0;
            private const byte StateOpen = 1;
            private const byte StateLunge = 2;
            private const byte StateRest = 3;
            private const byte StateDone = 4;
            // A plant is down for so long, comes up, is up for so long, and goes down.
            private const double PlantDown = 1.2;
            private const double PlantRise = 0.25;
            private const double PlantStay = 1.5;
            private const double PlantCycle = PlantDown + PlantRise + PlantStay + PlantRise;
            // A plant that is down stays down while the runner is less than this many seconds from it.
            private const double PlantHoldSeconds = 0.75;
            // The runner can be this deep in the top of a plant without a hit.
            private const double PlantSlack = 0.25;
            private const double BobSeconds = 1.3;
            private const double BobRows = 0.5;
            private const int FlockGap = 11;
            private const byte StateAway = 1;
            private const double ClimbSpeed = 7;

            // The seconds the runner needs before it meets the start or the end of a bridge, and after.
            private const double StartLead = 0.7;
            private const double StartTail = 0.4;
            private const double SpringTail = 1.3;
            private const double EndLead = 0.3;
            private const double EndTail = 0.7;
            // A jump for something comes down this long before it is met.
            private const double BesideLead = 0.15;
            // The dice add something every so many seconds when the run sends no failed tests, and when
            // it sends one every two and a half seconds or more; the failed tests of the last seconds count.
            private const double ExtraOften = 1.7;
            private const double ExtraSeldom = 7;
            private const double PressureSeconds = 8;
            private const double PressureFull = 3.2;
            private const double ExtraRetry = 0.25;
            private const double ExtraRoom = 10;

            // DC01. A run of this many tests has it, and it takes this many stomps.
            public const int BossFrom = 50;
            public const int BossHp = 4;
            public const int BossWide = 9;
            public const int BossRows = 6;
            private const int BossNone = 0;
            private const int BossArrives = 1;
            private const int BossThrows = 2;
            private const int BossWarns = 3;
            private const int BossCharges = 4;
            private const int BossBack = 5;
            private const int BossFalls = 6;
            private const int BossGone = 7;
            private static readonly string[] BossStates = { "none", "arrives", "throws", "warns", "charges", "back", "falls", "gone" };
            // The cells a second it comes on screen, charges and goes back, and the seconds it warns, falls and waits between two throws.
            private const double BossIn = 25;
            private const double BossCharge = 42;
            // With every stomp it took, DC01 charges this much faster and throws this much sooner, and
            // from the second stomp on it throws one more thing, one of them through the air.
            private const double BossChargeMore = 2;
            private const double BossThrowSooner = 0.1;
            private const int BossMoreFrom = 2;
            private const double BossOut = 70;
            private const double BossWarnSeconds = 0.7;
            public const double BossFallSeconds = 1.2;
            private const double BossThrowSeconds = 1.5;
            // It stands no further ahead of the runner than this, so that the fight is the same on a wide screen.
            private const double BossFar = 64;

            public const int LastCoin = 1;
            public const int LastStomp = 2;
            public const int LastHit = 3;
            public const int LastBite = 4;
            public const int LastAhead = 5;

            /// <summary>A name to draw over something: where, what, and whether it is the name of a coin, which gives way to the others.</summary>
            private struct Label
            {
                public int X;
                public int Row;
                public string Text;
                public byte Style;
                public string Short;
            }

            private readonly Random _random;
            private readonly List<RunResult> _queue = new List<RunResult>();
            private readonly List<Thing> _things = new List<Thing>();
            private readonly List<Platform> _platforms = new List<Platform>();
            private readonly List<Popup> _popups = new List<Popup>();
            private readonly List<int> _tones = new List<int>();
            private readonly List<Label> _labels = new List<Label>();
            private readonly List<int> _taken = new List<int>();
            private readonly double[] _clouds = new double[16];
            private int _cloudCount;
            private int _next;
            private int _width;
            private int _height;
            private int _ground;
            private int _runnerX;
            private int _levels;
            private double _time;
            private double _distance;
            private double _speed = BaseSpeed;
            private double _cursor;
            private double _y;
            private double _vy;
            private bool _supported = true;
            private int _jumps;
            private double _jumpKey = -10;
            private double _earlyUntil = -10;
            private double _landed = -10;
            private double _hitClock;
            private Platform _open;
            private double _openTime;
            private int _level;
            private int _onLevel;
            private int _stay = int.MaxValue;
            private int _passRun;
            private int _rest;
            private double _fallUntil;
            private double _arcX = double.NaN;
            private int _arcBase;
            private long _units;
            private int _form = FormFull;
            private double _extraAt = 2;
            private double _pressure;
            private int _boss;
            private double _bossAt;
            private double _bossClock;
            private int _bossShots;
            private bool _bossAir;

            public Runner(Random random)
            {
                _random = random;
                Lives = Hearts;
                Extras = true;
                BossGoneFor = -1;
            }

            /// <summary>The tests of the run: what the score is a share of.</summary>
            public int Total { get; set; }

            /// <summary>The dice add to the course: walkers, attacks, plants, birds, bridges beside the route, and the turns of the route itself.</summary>
            public bool Extras { get; set; }

            /// <summary>The run is near its end: it is time for DC01.</summary>
            public bool BossDue { get; set; }

            /// <summary>The tests of the run take too little time for a fight with DC01.</summary>
            public bool NoBoss { get; set; }

            /// <summary>The run is long enough for DC01, which is a tenth of the score then.</summary>
            public bool HasBoss { get { return Total >= BossFrom && !NoBoss; } }

            /// <summary>DC01 came on screen in this game.</summary>
            public bool BossCame { get { return _boss != BossNone; } }

            /// <summary>The tests stopped: what this game has not had by now, it will not have.</summary>
            public bool Ended { get; set; }

            /// <summary>
            /// The tests of the run that had not reached the runner when the tests stopped, with the
            /// runner running to the last: they are not in what the score is a share of.
            /// </summary>
            public int Forgiven { get; set; }

            /// <summary>The tests that have not reached the runner: of the results that wait, and of what is still ahead on the course.</summary>
            public int Unmet
            {
                get
                {
                    int tests = _queue.Count - _next;
                    double left = _distance + _runnerX;
                    foreach (var t in _things)
                    {
                        if (!t.Gone && t.Count > 0 && t.X + t.Width > left) tests += t.Count;
                    }
                    return tests;
                }
            }

            /// <summary>
            /// DC01 is a tenth of the score of a game it can still come to, or came to. A game that is
            /// over, or whose run is, without DC01 ever on its screen, is not held to it.
            /// </summary>
            private bool BossCounts { get { return HasBoss && (BossCame || !(Over || Ended)); } }

            /// <summary>The stomps DC01 took, of BossHp, and whether it is decommissioned.</summary>
            public int BossHits { get; private set; }

            public bool BossDown { get { return _boss >= BossFalls; } }

            /// <summary>The seconds since DC01 was decommissioned and gone, or -1.</summary>
            public double BossGoneFor { get; private set; }

            public bool Paused { get; set; }
            public int Coins { get; private set; }
            public int Stomps { get; private set; }
            public int Hits { get; private set; }
            public int Streak { get; private set; }
            public int BestStreak { get; private set; }

            /// <summary>The hearts that are left, of three.</summary>
            public int Lives { get; private set; }

            /// <summary>The last heart is gone: nothing moves any more but the runner going down, for OverFor seconds so far.</summary>
            public bool Over { get; private set; }

            public double OverFor { get; private set; }

            /// <summary>
            /// What happened last (LastCoin, LastStomp, LastHit, LastBite for a hit by a lunge, LastAhead
            /// for a giant or DC01 that came on the course, or 0 for nothing yet), to which test, for how
            /// many points and how many results. LastFree: it was not a test, and was worth nothing.
            /// </summary>
            public int LastKind { get; private set; }

            public string LastId { get; private set; }
            public string LastTitle { get; private set; }
            public int LastPoints { get; private set; }
            public int LastCount { get; private set; }
            public bool LastFree { get; private set; }

            /// <summary>The results that are not on the course yet.</summary>
            public int Waiting { get { return _queue.Count - _next; } }

            /// <summary>How much faster than at the start the world goes by: 1 to 1.6.</summary>
            public double Pace { get { return _speed / BaseSpeed; } }

            /// <summary>The row of the ground, and the rows above it that the game is played in.</summary>
            public int Ground { get { return _ground; } }

            public int Score
            {
                get
                {
                    if (Total <= 0) return 0;
                    long share = 1000L * Math.Max(1, Total - Forgiven);
                    if (!BossCounts) return (int)Math.Min(GameFullScore, _units * GameFullScore / share);
                    return (int)Math.Min(GameTestsScore, _units * GameTestsScore / share) + GameBossScore * BossHits / BossHp;
                }
            }

            /// <summary>A result joins the queue: ResultPassed, ResultFailed plus its severity, ResultError, ResultInvestigate or ResultOther.</summary>
            public void Enqueue(byte kind, string id, string title)
            {
                _queue.Add(new RunResult { Kind = kind, Id = id ?? string.Empty, Title = title });
            }

            /// <summary>
            /// Moves the sounds the game asked for since the last call to <paramref name="into"/>: a jump, a
            /// second jump, a coin, a stomp, a hit, a streak that reached ten more, the snap of a lunge, a
            /// heart that came back, the end of the game, DC01 going down.
            /// </summary>
            public void TakeTones(List<int> into)
            {
                into.AddRange(_tones);
                _tones.Clear();
            }

            /// <summary>
            /// What is on the course, a line each, for tests. The runner: its rows above the ground, its
            /// speed upwards, its hearts, the speed of the world, the seconds it still stumbles, whether
            /// it stands, and the jumps it used. A bridge: where it starts and ends, in cells ahead of
            /// the right side of the runner, its rows above the ground, and whether it is of the route.
            /// Everything else, DC01 among it: its kind, the cells it is ahead, the rows of its lowest row
            /// above the ground, its width, its height as it is now, what it does, the results it stands
            /// for (for DC01 the stomps it still takes), and its name.
            /// </summary>
            public void Describe(List<string> into)
            {
                var c = CultureInfo.InvariantCulture;
                double right = Front;
                into.Add(string.Format(c, "Runner {0:0.00} {1:0.00} {2} {3:0.00} {4:0.00} {5} {6}", _y, _vy, Lives, _speed, Math.Max(0, _hitClock), Over ? "over" : (_supported ? "stands" : "air"), _jumps));
                foreach (var p in _platforms)
                {
                    into.Add(string.Format(c, "Platform {0:0.00} {1} {2} {3}", p.From - right, p.To >= double.MaxValue ? "open" : (p.To - right).ToString("0.00", c), p.Surface, p.Route ? "route" : "beside"));
                }
                foreach (var t in _things)
                {
                    if (t.Gone) continue;
                    double y = t.Base;
                    double height = t.Height;
                    string state = "-";
                    if (t.Kind == KindBird)
                    {
                        y = BirdY(t);
                        state = t.State == StateAway ? "away" : "flies";
                    }
                    else if (t.Kind == KindPlant)
                    {
                        height = 1 + PlantUp(t);
                        state = PlantUp(t) >= 0.5 ? "up" : "down";
                    }
                    else if (t.Kind == KindBiter || t.Kind == KindBrute)
                    {
                        state = t.State == StateOpen ? "opens" : (t.State == StateLunge ? "lunges" : (t.State == StateWalk ? "walks" : "lunged"));
                    }
                    else if (t.Kind != KindCoin && t.Kind != KindSpring)
                    {
                        state = "walks";
                    }
                    into.Add(string.Format(c, "{0} {1:0.00} {2:0.00} {3} {4:0.00} {5} {6} {7}", GameKindNames[t.Kind], t.X - right, y, t.Width, height, state, t.Count, t.Named || t.Kind == KindCoin ? t.Id : "-"));
                }
                if (_boss != BossNone && _boss != BossGone)
                {
                    into.Add(string.Format(c, "Boss {0:0.00} 0.00 {1} {2}.00 {3} {4} DC01", _bossAt, BossWide, BossRows, BossStates[_boss], BossHp - BossHits));
                }
            }

            // ---------------------------------------------------------------- the playfield

            /// <summary>
            /// The size of the playfield. The world stays as it is: a new size shows more or less of it.
            /// From the bottom: a few rows under the ground, the ground, and the rest is sky, which has
            /// room for two levels of bridges on a low screen and for up to four on a tall one.
            /// </summary>
            public void Layout(int width, int height)
            {
                if (width == _width && height == _height) return;
                bool first = _width == 0;
                _width = width;
                _height = height;
                int under = height >= 40 ? 4 : (height >= 28 ? 3 : 1);
                _ground = height - 1 - under;
                _runnerX = Math.Max(8, Math.Min(22, width / 7));
                // Two levels, and more where the screen is tall: above the highest of them there is room
                // for what stands on it, for a bird that turned away, and for the counter of the run.
                _levels = Math.Max(2, Math.Min(LevelsMost, (_ground - SkyRows - 6) / LevelRows));
                if (!first) return;
                _cursor = width;
                Level(0);
                // A cloud for every thirty cells of the screen or so.
                _cloudCount = Math.Max(3, Math.Min(_clouds.Length / 2, width / 30));
                for (int i = 0; i < _cloudCount * 2; i += 2)
                {
                    _clouds[i] = _random.Next(width + 40);
                    _clouds[i + 1] = 1 + _random.Next(Math.Max(1, _ground / 3));
                }
            }

            // ---------------------------------------------------------------- the key

            /// <summary>
            /// The jump key: a jump from the ground or from a bridge, and a second jump in the air. A
            /// key that is held is reported as the key again and again, so a key that comes at once after
            /// the last one is not a second jump; it counts when the runner lands, as does a key that was
            /// a moment early. A jump from a spring is twice as high.
            /// </summary>
            public void Jump()
            {
                if (Paused || Over || _width == 0) return;
                double since = _time - _jumpKey;
                _jumpKey = _time;
                if (_supported)
                {
                    Leap(false);
                }
                else if (_jumps < 2 && since > RepeatSeconds)
                {
                    Leap(true);
                }
                else
                {
                    _earlyUntil = _time + EarlySeconds;
                }
            }

            private void Leap(bool second)
            {
                bool spring = !second && OnSpring();
                _vy = spring ? SpringSpeed : JumpSpeed;
                _supported = false;
                _jumps = second ? 2 : 1;
                _earlyUntil = -10;
                _tones.Add(second || spring ? ToneDouble : ToneJump);
            }

            /// <summary>Whether the feet of the runner are on a spring.</summary>
            private bool OnSpring()
            {
                double left = _distance + _runnerX;
                foreach (var t in _things)
                {
                    if (t.Kind == KindSpring && Math.Abs(t.Base - _y) < 0.5 && t.X < left + RunnerWidth - 1 && t.X + t.Width > left + 1) return true;
                }
                return false;
            }

            // ---------------------------------------------------------------- time

            /// <summary>Moves the game on by the time that passed, in steps of a fortieth of a second at most.</summary>
            public void Step(double seconds)
            {
                if (Paused || _width == 0) return;
                while (seconds > 1e-9)
                {
                    double step = Math.Min(GameLongestStep, seconds);
                    seconds -= step;
                    if (Over)
                    {
                        // The world stands still. The runner comes down, if it was in the air, and goes down.
                        OverFor += step;
                        MoveRunner(step);
                    }
                    else
                    {
                        Tick(step);
                    }
                }
            }

            private void Tick(double seconds)
            {
                _time += seconds;
                // The streak makes the world go by faster, up to a limit, and it gets there smoothly.
                double want = BaseSpeed * (1 + Math.Min(SpeedMost, Streak * SpeedPerStreak));
                _speed += Math.Max(-SpeedChange * seconds, Math.Min(SpeedChange * seconds, want - _speed));
                _distance += _speed * seconds;
                if (_hitClock > 0) _hitClock -= seconds;
                _pressure -= _pressure * seconds / PressureSeconds;
                Build();
                MoveRunner(seconds);
                MoveThings(seconds);
                MoveBoss(seconds);
                Touch();
                for (int i = _popups.Count - 1; i >= 0; i--)
                {
                    _popups[i].Age += seconds;
                    if (_popups[i].Age > PopupSeconds) _popups.RemoveAt(i);
                }
            }

            /// <summary>The world cell that is just past the right edge of the screen: where the course grows.</summary>
            private double Edge { get { return _distance + _width + 2; } }

            /// <summary>The world cell of the right side of the runner: what is ahead is measured from here.</summary>
            private double Front { get { return _distance + _runnerX + RunnerWidth; } }

            // ---------------------------------------------------------------- room

            private static double Lead(byte kind) { return kind == KindGiant ? 1.0 : (kind == KindPlant || kind == KindBird ? 0.5 : 0.55); }

            private static double Tail(byte kind) { return kind == KindGiant ? 0.8 : (kind == KindPlant || kind == KindBird ? 0.6 : 0.55); }

            /// <summary>The levels from one to another, as the bits of a number: the ground is the first.</summary>
            private static int Span(int from, int to)
            {
                int bits = 0;
                for (int i = Math.Max(0, from); i <= to; i++) bits |= 1 << i;
                return bits;
            }

            /// <summary>
            /// The levels something is in the way at: the one it is on, and the one above it, where the
            /// jump over it goes. The giant is in the way of the second jump too. A bird counts for the
            /// level whose floor it flies over. <paramref name="y"/> is the rows of its lowest row above the ground.
            /// </summary>
            private static int Levels(byte kind, double y)
            {
                int level = (int)((kind == KindBird ? y - 1 : y) / LevelRows);
                return Span(level, level + (kind == KindGiant ? 2 : 1));
            }

            private static int Levels(Thing t) { return Levels(t.Kind, t.Kind == KindBird ? t.Y : t.Base); }

            /// <summary>
            /// Whether something leaves the runner the time it needs, with the world going by at
            /// <paramref name="v"/>. It is at <paramref name="x"/>, comes at <paramref name="speed"/>, is in
            /// the way at the levels <paramref name="levels"/>, and takes the runner <paramref name="lead"/>
            /// seconds before it is met and <paramref name="tail"/> after: the moment the runner meets it
            /// must not be within the seconds that something else in its way takes. <paramref name="self"/>
            /// is the thing itself when it is on the course already. Without <paramref name="birds"/> the
            /// birds do not count, and with <paramref name="ahead"/> only what the runner meets first.
            /// </summary>
            private bool Clear(Thing self, int levels, double lead, double tail, double x, double speed, double v, bool birds, bool ahead)
            {
                double front = Front;
                double at = (x - front) / (v + speed);
                foreach (var t in _things)
                {
                    if (t == self || t.Gone || t.Kind == KindCoin || t.Kind == KindSpring) continue;
                    if (t.Kind == KindBird && (!birds || t.State == StateAway)) continue;
                    if ((levels & Levels(t)) == 0) continue;
                    double other = (t.X - front) / (v + t.Speed);
                    if (ahead && other >= at) continue;
                    if (at - lead < other + Tail(t.Kind) && other - Lead(t.Kind) < at + tail) return false;
                    // What stands in its place cannot give way later. For it, a creature in front of it
                    // counts as one that may stand still as well, and be met that much later.
                    if (speed > 0 || t.Speed <= 0 || t.Kind == KindBird || t.X >= x) continue;
                    other = (t.X - front) / v;
                    if (at - lead < other + Tail(t.Kind) && other - Lead(t.Kind) < at + tail) return false;
                }
                int floor = 0;
                while ((levels >> floor & 1) == 0 && floor < LevelsMost + 2) floor++;
                foreach (var p in _platforms)
                {
                    // A bridge beside the route is over the heads of what is under it. A jump from under
                    // it comes down on the bridge and not on what the jump was for, and the giant is as
                    // high as the bridge. So nothing that is in the way is met under one.
                    if (!p.Route && p.Level > floor && (levels & 1 << p.Level) != 0)
                    {
                        double from = (p.From - front) / v;
                        if (!(ahead && from >= at) && at > from - BesideLead && at - lead < (p.To - front) / v) return false;
                    }
                    // Where the runner jumps up to it, and where it ends and the runner comes down from it.
                    if (p.Climb && (levels & Span(p.Low, p.Level)) != 0)
                    {
                        // A jump from a spring takes longer to come down.
                        double start = (p.From - front) / v;
                        if (!(ahead && start >= at) && at - lead < start + (p.Level - p.Low > 1 ? SpringTail : StartTail) && start - StartLead < at + tail) return false;
                    }
                    if (p.To >= double.MaxValue || (levels & Span(p.Down, p.Level)) == 0) continue;
                    double end = (p.To - front) / v;
                    if (!(ahead && end >= at) && at - lead < end + EndTail && end - EndLead < at + tail) return false;
                }
                return true;
            }

            /// <summary>
            /// Whether something new fits on the course: at the speed the world has now, at the slowest it
            /// can have when the runner is hit, and at a faster one for a streak that grows.
            /// </summary>
            private bool Fits(int levels, double lead, double tail, double x, double speed)
            {
                return Clear(null, levels, lead, tail, x, speed, _speed, true, false) && Clear(null, levels, lead, tail, x, speed, BaseSpeed, true, false) &&
                    Clear(null, levels, lead, tail, x, speed, Math.Min(BaseSpeed * (1 + SpeedMost), _speed + 5), true, false);
            }

            private bool Fits(byte kind, double x, double y)
            {
                return Fits(Levels(kind, y), Lead(kind), Tail(kind), x, KindSpeed(kind));
            }

            private static double KindSpeed(byte kind)
            {
                switch (kind)
                {
                    case KindWalker: return WalkerSpeed;
                    case KindAttack: return AttackSpeed;
                    case KindBiter: return BiterSpeed;
                    case KindBrute: return BruteSpeed;
                    case KindGiant: return GiantSpeed;
                    case KindBird: return BirdSpeed;
                    case KindPacket: return PacketSpeed;
                    default: return 0;
                }
            }

            // ---------------------------------------------------------------- the course

            /// <summary>
            /// Puts what waits in the queue on the route, as long as there is room at the edge: one result
            /// for a piece, or, when more wait than can be played one at a time, the next few results for a
            /// coin (the passed tests among them) and a creature (the failed ones). Then the dice. While
            /// DC01 is there the results wait.
            /// </summary>
            private void Build()
            {
                double edge = Edge;
                // A bridge that got nothing for a moment, with nothing waiting for room either, ends
                // where the screen ends now, or past its last piece when that is further.
                if (_open != null && _next >= _queue.Count && _time - _openTime > PlatformHoldSeconds)
                {
                    double end = Ending(Math.Max(edge, _cursor - CoinGap + 1), 0);
                    ClosePlatform(end, 0);
                    _cursor = Math.Max(_cursor, end + Fall(_level));
                    Level(0);
                }
                if (_boss != BossNone && _boss != BossGone) return;
                if (BossDue && HasBoss && _boss == BossNone)
                {
                    StartBoss(edge);
                    return;
                }
                while (_next < _queue.Count && _cursor <= edge)
                {
                    byte first = _queue[_next].Kind;
                    if (first == ResultOther)
                    {
                        _next++;
                        continue;
                    }
                    int waiting = _queue.Count - _next;
                    int size = waiting <= GroupFrom ? 1 : (waiting + GroupPieces - 1) / GroupPieces;
                    // One at a time, a test to investigate is a bird: it needs no room on the route.
                    if (size == 1 && first == ResultInvestigate)
                    {
                        AddBird(edge, _queue[_next]);
                        _next++;
                        continue;
                    }
                    // The next results, as many as the pieces take: how many passed, how many failed, and
                    // the first passed test and the most severe failed one, which the pieces are named
                    // for. In a piece for several results what neither passed nor failed is left out;
                    // one at a time, an error is a plant.
                    int passed = 0;
                    int failed = 0;
                    int coin = -1;
                    int creature = -1;
                    int at = _next;
                    bool plant = size == 1 && first == ResultError;
                    for (; !plant && at < _queue.Count && passed + failed < size; at++)
                    {
                        byte kind = _queue[at].Kind;
                        if (kind == ResultPassed)
                        {
                            passed++;
                            if (coin < 0) coin = at;
                        }
                        else if (kind >= ResultFailed && kind < ResultError)
                        {
                            failed++;
                            if (creature < 0 || kind < _queue[creature].Kind) creature = at;
                        }
                    }
                    if (plant) at = _next + 1;
                    // The passed tests that wait right behind are of the same run of them.
                    int run = failed > 0 || plant ? 0 : _passRun + passed;
                    for (int i = at; run > 0 && i < _queue.Count && run < PlatformFrom; i++)
                    {
                        if (_queue[i].Kind == ResultOther || _queue[i].Kind == ResultInvestigate) continue;
                        if (_queue[i].Kind != ResultPassed) break;
                        run++;
                    }
                    // The route goes to another level when it is time. The piece is where it leads.
                    if (TurnDue(run >= PlatformFrom)) Turn(Math.Max(_cursor, edge), run >= PlatformFrom);
                    double x = Math.Max(_cursor, edge);
                    int floor = _level * LevelRows;
                    if (plant)
                    {
                        if (!Fits(KindPlant, x, floor)) break;
                        AddPlant(x, floor, _queue[_next]);
                    }
                    else
                    {
                        // The coin of a step up is in the air before the bridge, when the step is still at the edge.
                        bool arc = passed > 0 && !double.IsNaN(_arcX) && _arcX >= edge - 1;
                        double coinX = arc ? _arcX : x;
                        double creatureX = x;
                        byte creatureKind = KindBiter;
                        if (failed > 0)
                        {
                            int severity = Math.Min(GameOtherSeverity, _queue[creature].Kind - ResultFailed);
                            creatureKind = severity == 0 ? KindGiant : (severity == 1 ? KindBrute : KindBiter);
                            // A coin can be right in front of it. And it waits for room.
                            if (passed > 0 && !arc) creatureX += (passed > 1 ? 3 : 2) + CoinGap;
                            if (!Fits(creatureKind, creatureX, floor)) break;
                        }
                        if (passed > 0) PlaceCoin(coinX, arc ? _arcBase : floor + 1, passed, _queue[coin], arc);
                        if (failed > 0) PlaceCreature(creatureX, floor, creatureKind, failed, _queue[creature]);
                        _passRun = failed > 0 ? 0 : _passRun + passed;
                    }
                    _arcX = double.NaN;
                    _next = at;
                    _onLevel++;
                    if (_rest > 0) _rest--;
                    if (_open != null) _openTime = _time;
                }
                Scatter(edge);
            }

            /// <summary>
            /// Whether the route goes to another level before the next piece. From the ground it goes up
            /// when four passed tests or more follow one another, and, with the dice, after a few pieces.
            /// A bridge has room for a few pieces.
            /// </summary>
            private bool TurnDue(bool streak)
            {
                if (_level > 0) return _onLevel >= _stay;
                if (_rest > 0) return false;
                return streak || (Extras && _onLevel >= _stay);
            }

            /// <summary>
            /// The route goes to another level, where the piece that is due at <paramref name="x"/> would
            /// have been. Up one level with a jump: from the ground the bridge starts where the runner is
            /// done with what is before it, and from a bridge the new one starts over the end of the old.
            /// Up two with a spring. Or down, to a bridge under the end of this one or to the ground.
            /// Without the dice it goes up as long as the passed tests go on, and then to the ground for
            /// three pieces.
            /// </summary>
            private void Turn(double x, bool streak)
            {
                int to;
                bool spring = false;
                if (_level < _levels && (_level == 0 || (Extras ? _random.Next(100) < 55 : streak)))
                {
                    to = _level + 1;
                    if (Extras && to < _levels && _random.Next(4) == 0)
                    {
                        to++;
                        spring = true;
                    }
                }
                else
                {
                    to = Extras && _level > 1 && _random.Next(2) == 0 ? _random.Next(1, _level) : 0;
                }
                _arcX = double.NaN;
                if (to < _level)
                {
                    // Down: the bridge ends, and one of the level it goes to is under its end already.
                    // The next piece is where the runner has come down far enough to have it.
                    x = Ending(x - 2, to) + 2;
                    ClosePlatform(x - 2, to);
                    if (to > 0) Open(x - 8, to, to, false);
                    if (to == 0 && !Extras) _rest = GroundCoins;
                    _cursor = Math.Max(_cursor, x - 2 + Fall(_level - to));
                }
                else
                {
                    // Up: where there is room for the jump.
                    double from = _level == 0 ? x + PlatformAfter - PlatformLead + ArcBack : x + StepFrom;
                    if (spring) from = x + 2;
                    for (int tries = 0; tries < 12 && !Fits(Span(_level, to), StartLead, spring ? SpringTail : StartTail, from, 0); tries++) from += 6;
                    if (spring)
                    {
                        // The spring is on this floor, the bridge two levels up starts over it, and this
                        // floor goes on a little for a runner that did not take it.
                        _things.Add(new Thing { Kind = KindSpring, X = from, Width = GameKindWidth[KindSpring], Height = 1, Base = _level * LevelRows, Id = "a spring" });
                        if (_open != null) ClosePlatform(from + 16, 0);
                        Open(from - 3, to, _level, true);
                        _cursor = Math.Max(_cursor, from + SpringLand);
                    }
                    else
                    {
                        _arcX = from - ArcBack;
                        _arcBase = _level * LevelRows + ArcRows;
                        if (_open != null) ClosePlatform(from + StepOver, _level);
                        Open(from, to, _level, true);
                        _cursor = Math.Max(_cursor, from + (_level == 0 ? PlatformLead : StepCoin - StepFrom));
                    }
                }
                Level(to);
            }

            /// <summary>
            /// Where the bridge of the route can end, from a cell on, when the runner comes down from it
            /// to a level: where the runner is done with what is on the bridge before that.
            /// </summary>
            private double Ending(double end, int down)
            {
                for (int tries = 0; tries < 12 && !Fits(Span(down, _level), EndLead, EndTail, end, 0); tries++) end += 6;
                return end;
            }

            /// <summary>
            /// The cells the world goes by, at its fastest, while a runner that comes off the end of a
            /// bridge falls so many levels to where a coin on the floor below is in its reach.
            /// </summary>
            private static double Fall(int levels)
            {
                double rows = Math.Max(0, levels * LevelRows - RunnerRows - CoinReach + 0.5);
                return 3 + BaseSpeed * (1 + SpeedMost) * Math.Sqrt(2 * rows / Gravity);
            }

            /// <summary>The route is on a level from now on, for so many pieces.</summary>
            private void Level(int level)
            {
                _level = level;
                _onLevel = 0;
                if (level == 0) _open = null;
                _stay = !Extras ? (level == 0 ? int.MaxValue : PlatformCoins) : (level == 0 ? 3 + _random.Next(4) : 4 + _random.Next(4));
            }

            private void Open(double from, int level, int low, bool climb)
            {
                _open = new Platform { From = from, To = double.MaxValue, Level = level, Surface = level * LevelRows, Route = true, Climb = climb, Low = low };
                _platforms.Add(_open);
                _openTime = _time;
            }

            /// <summary>
            /// The open bridge of the route ends, and the runner comes down from it to a level. No bridge
            /// beside the route is in the way of that: one between the two levels ends before it, or is
            /// not there at all, and none is put there for a while.
            /// </summary>
            private void ClosePlatform(double to, int down)
            {
                if (_open == null) return;
                _open.To = Math.Max(_open.From + 6, to);
                _open.Down = down;
                double end = _open.To;
                int level = _open.Level;
                _open = null;
                if (level - down < 2) return;
                _fallUntil = end + Fall(level - down) + 12;
                for (int i = _platforms.Count - 1; i >= 0; i--)
                {
                    var p = _platforms[i];
                    if (p.Route || p.Level >= level || p.Level <= down || p.To <= end - 6 || p.From >= _fallUntil) continue;
                    if (p.From >= end - 12) _platforms.RemoveAt(i);
                    else p.To = end - 6;
                }
            }

            private void PlaceCoin(double x, int floor, int count, RunResult result, bool arc)
            {
                bool large = count > 1;
                _things.Add(new Thing { Kind = KindCoin, X = x, Width = large ? 3 : 2, Height = 2, Base = floor, Count = count, Id = result.Id, Title = result.Title, Test = true });
                if (!arc) _cursor = x + (large ? 3 : 2) + CoinGap;
            }

            private void PlaceCreature(double x, int floor, byte kind, int count, RunResult result)
            {
                _pressure += 1;
                int severity = Math.Min(GameOtherSeverity, result.Kind - ResultFailed);
                int width = count > 1 ? 9 : GameKindWidth[kind];
                _things.Add(new Thing
                {
                    Kind = kind, X = x, Width = width, Height = GameKindRows[kind], Base = floor, Speed = KindSpeed(kind), Severity = severity, Count = count,
                    Id = result.Id, Title = result.Title, Named = true, Test = true
                });
                // A coin can be right behind it.
                _cursor = x + width + CoinGap;
                // The giant is announced: it takes the second jump.
                if (kind == KindGiant) Note(LastAhead, result.Id, result.Title, 0, count, false);
            }

            /// <summary>A plant on a floor: for a test that ended in an error, with its ID, or of the dice.</summary>
            private void AddPlant(double x, int floor, RunResult? result)
            {
                var plant = new Thing { Kind = KindPlant, X = x, Width = GameKindWidth[KindPlant], Height = GameKindRows[KindPlant], Base = floor, Id = "a plant", Clock = _random.NextDouble() * PlantCycle };
                if (result.HasValue)
                {
                    _passRun = 0;
                    _pressure += 1;
                    plant.Id = result.Value.Id;
                    plant.Title = result.Value.Title;
                    plant.Named = true;
                    plant.Test = true;
                    _cursor = x + plant.Width + CoinGap;
                }
                _things.Add(plant);
            }

            /// <summary>
            /// A bird for a test to investigate, with its ID: at the height of a runner on the route. One
            /// that would be in the way of something flies high from the start.
            /// </summary>
            private void AddBird(double x, RunResult result)
            {
                double y = _level * LevelRows + (_level == 0 ? LevelRows + 1 : 1);
                var bird = new Thing
                {
                    Kind = KindBird, X = x, Y = y, Base = (int)y, Width = GameKindWidth[KindBird], Height = GameKindRows[KindBird], Speed = BirdSpeed,
                    Id = result.Id, Title = result.Title, Named = true, Test = true
                };
                if (!Fits(KindBird, x, y)) bird.State = StateAway;
                _things.Add(bird);
            }

            /// <summary>
            /// The dice. When nothing of the run waits and it is time, one more thing at the edge of the
            /// screen: on the floor of the route a walker, an attack or a plant; a bird or a line of them
            /// at the height of a runner there; or a bridge beside the route. What does not fit there now
            /// is tried again in a moment.
            /// </summary>
            private void Scatter(double edge)
            {
                if (!Extras || _time < _extraAt) return;
                if (_next < _queue.Count)
                {
                    _extraAt = _time + ExtraRetry;
                    return;
                }
                // Not on top of what is at the edge already.
                foreach (var t in _things)
                {
                    if (!t.Gone && t.X + t.Width > edge - ExtraRoom && t.X < edge + ExtraRoom)
                    {
                        _extraAt = _time + ExtraRetry;
                        return;
                    }
                }
                int floor = _level * LevelRows;
                int dice = _random.Next(100);
                bool placed;
                if (dice < 44)
                {
                    byte kind = dice < 22 ? KindWalker : KindAttack;
                    placed = Fits(kind, edge, floor);
                    if (placed)
                    {
                        string[] names = kind == KindWalker ? GameHabits : GameAttacks;
                        _things.Add(new Thing
                        {
                            Kind = kind, X = edge, Width = GameKindWidth[kind], Height = GameKindRows[kind], Base = floor, Speed = KindSpeed(kind),
                            Id = names[_random.Next(names.Length)], Title = kind == KindWalker ? "a habit, not a test" : "an attack, not a test", Named = true
                        });
                    }
                }
                else if (dice < 58)
                {
                    placed = Fits(KindPlant, edge, floor);
                    if (placed) AddPlant(edge, floor, null);
                }
                else if (dice < 84)
                {
                    // Not over the last pieces of a bridge: it ends there. On a bridge they come in lines.
                    int line = _random.Next(10);
                    placed = (_level == 0 || _onLevel < _stay - 1) && Flock(edge, floor + (_level == 0 ? LevelRows + 1 : 1), _level == 0 || line < 6 ? 1 : (line < 9 ? 2 : 3));
                }
                else
                {
                    placed = AddBridge(edge);
                }
                if (!placed)
                {
                    _extraAt = _time + ExtraRetry;
                    return;
                }
                double every = ExtraOften + (ExtraSeldom - ExtraOften) * Math.Min(1, _pressure / PressureFull);
                // A bridge is not a free ride.
                if (_level > 0) every *= 0.75;
                _extraAt = _time + every * (0.6 + 0.8 * _random.NextDouble());
            }

            /// <summary>
            /// Birds of the dice in a line, each with the name of a threat actor, so far apart that a
            /// runner that bounces off one comes down on the next or behind it. False when one of them
            /// would not fit.
            /// </summary>
            private bool Flock(double x, double y, int count)
            {
                for (int i = 0; i < count; i++)
                {
                    if (!Fits(KindBird, x + i * FlockGap, y)) return false;
                }
                for (int i = 0; i < count; i++)
                {
                    _things.Add(new Thing
                    {
                        Kind = KindBird, X = x + i * FlockGap, Y = y, Base = (int)y, Width = GameKindWidth[KindBird], Height = GameKindRows[KindBird],
                        Speed = BirdSpeed, Id = GameActors[_random.Next(GameActors.Length)], Title = "a threat actor, not a test", Named = true
                    });
                }
                return true;
            }

            /// <summary>
            /// A bridge beside the route, one level above it, and now and then a second one a level higher
            /// that starts over the end of the first: room to move in. Nothing of the run is put on them,
            /// and where one ends the runner comes down as from any bridge. False where a bridge of that
            /// level is already.
            /// </summary>
            private bool AddBridge(double edge)
            {
                int level = _level + 1;
                if (level > _levels || edge < _fallUntil) return false;
                double from = edge + 2;
                for (int n = 0; n < 2 && level <= _levels; n++, level++)
                {
                    foreach (var p in _platforms)
                    {
                        if (p.Level == level && p.To > from - 12) return n > 0;
                    }
                    double to = from + 18 + _random.Next(20);
                    _platforms.Add(new Platform { From = from, To = to, Level = level, Surface = level * LevelRows, Low = level - 1 });
                    if (_random.Next(2) == 0) break;
                    from = to - 7;
                }
                return true;
            }

            private Platform PlatformUnder(double x, int surface)
            {
                foreach (var p in _platforms)
                {
                    if (p.Surface == surface && x >= p.From && x < p.To) return p;
                }
                return null;
            }

            // ---------------------------------------------------------------- what moves

            private void MoveRunner(double seconds)
            {
                double centre = _distance + _runnerX + RunnerWidth / 2.0;
                // The bridge under the feet ended: the runner falls, and has a jump left.
                if (_supported && _y > 0 && PlatformUnder(centre, (int)_y) == null)
                {
                    _supported = false;
                    _vy = 0;
                    _jumps = 1;
                }
                if (_supported) return;
                double before = _y;
                _y += _vy * seconds - Gravity * seconds * seconds / 2;
                _vy -= Gravity * seconds;
                if (_vy >= 0) return;
                // The highest floor that the feet came down through: a bridge, or the ground.
                int floor = _y <= 0 ? 0 : -1;
                foreach (var p in _platforms)
                {
                    if (centre >= p.From && centre < p.To && before >= p.Surface && _y < p.Surface) floor = Math.Max(floor, p.Surface);
                }
                if (floor < 0) return;
                _y = floor;
                _vy = 0;
                _supported = true;
                _jumps = 0;
                _landed = _time;
                if (_time <= _earlyUntil) Leap(false);
            }

            private void MoveThings(double seconds)
            {
                double left = _distance - 12;
                double front = Front;
                for (int i = _things.Count - 1; i >= 0; i--)
                {
                    var t = _things[i];
                    if (t.Gone)
                    {
                        t.GoneFor += seconds;
                        if (t.GoneFor > GoneSeconds) _things.RemoveAt(i);
                        continue;
                    }
                    if (t.X + t.Width < left)
                    {
                        _things.RemoveAt(i);
                        continue;
                    }
                    switch (t.Kind)
                    {
                        case KindCoin:
                        case KindSpring:
                            break;
                        case KindPlant:
                            // It does not come up under the runner, or right in front of it.
                            bool near = t.X - front < PlantHoldSeconds * _speed && t.X + t.Width > front - RunnerWidth - 2;
                            if (near && t.Clock <= PlantDown && t.Clock + seconds > PlantDown) break;
                            t.Clock += seconds;
                            if (t.Clock >= PlantCycle) t.Clock -= PlantCycle;
                            break;
                        case KindBird:
                            t.X -= t.Speed * seconds;
                            t.Clock += seconds;
                            if (t.State == StateAway)
                            {
                                t.Y = Math.Min(Sky, t.Y + ClimbSpeed * seconds);
                            }
                            else if (t.X + t.Width > front - RunnerWidth && !Clear(t, Levels(t), Lead(KindBird), Tail(KindBird), t.X, t.Speed, _speed, false, false))
                            {
                                // It would be in the way of something the runner has to do: it turns away.
                                t.State = StateAway;
                            }
                            break;
                        case KindBiter:
                        case KindBrute:
                            Bite(t, seconds, front);
                            break;
                        default:
                            Walk(t, seconds);
                            break;
                    }
                }
                for (int i = _platforms.Count - 1; i >= 0; i--)
                {
                    if (_platforms[i].To < left) _platforms.RemoveAt(i);
                }
            }

            /// <summary>
            /// The rows above the ground where a bird that turned away flies: over everything that is on
            /// the course, and under the counter of the run.
            /// </summary>
            private double Sky { get { return _levels * LevelRows + 7; } }

            /// <summary>The levels of the course.</summary>
            public int LevelCount { get { return _levels; } }

            /// <summary>
            /// The rows at the top of the playfield that nothing of the course is in: above the highest
            /// level, what stands on it with its name, and the birds that turned away. A jump from the
            /// highest level goes through them, and nothing else.
            /// </summary>
            public int SkyFree { get { return Math.Max(0, _ground - _levels * LevelRows - SkyRows); } }

            /// <summary>
            /// A creature walks towards the runner, along the floor it is on: one that is on a bridge
            /// stands where the bridge starts. It keeps its distance from what the runner meets before
            /// it, and from the end of a bridge the runner comes down from: it stands until there is
            /// room again.
            /// </summary>
            private void Walk(Thing t, double seconds)
            {
                double x = t.X - t.Speed * seconds;
                if (t.Base > 0 && PlatformUnder(x, t.Base) == null && PlatformUnder(t.X, t.Base) != null) return;
                if (Clear(t, Levels(t), Lead(t.Kind), Tail(t.Kind), x, t.Speed, _speed, false, true)) t.X = x;
            }

            /// <summary>
            /// A biter or a brute. It walks until the runner is on its floor and near: then it opens its
            /// mouth and stands, for long enough to be answered with a jump, lunges, and stands for a
            /// moment. It does that once. A runner that is in the air by then is not lunged at.
            /// </summary>
            private void Bite(Thing t, double seconds, double front)
            {
                switch (t.State)
                {
                    case StateOpen:
                        t.Clock += seconds;
                        if (t.Clock >= LungeWait)
                        {
                            t.State = StateLunge;
                            t.Clock = 0;
                        }
                        break;
                    case StateLunge:
                        t.X -= (t.Kind == KindBrute ? BruteLunge : BiterLunge) * seconds;
                        t.Clock += seconds;
                        if (t.Clock >= LungeSeconds)
                        {
                            t.State = StateRest;
                            t.Clock = 0;
                        }
                        break;
                    case StateRest:
                        t.Clock += seconds;
                        if (t.Clock >= LungeRest) t.State = StateDone;
                        break;
                    case StateWalk:
                        double gap = t.X - front;
                        if (gap <= LungeAhead * _speed && gap >= LungeWait * _speed + 1.5 && _supported && Math.Abs(_y - t.Base) < 0.5 && _time - _landed >= SettleSeconds && _hitClock <= 0)
                        {
                            t.State = StateOpen;
                            t.Clock = 0;
                            _tones.Add(ToneSnap);
                        }
                        else
                        {
                            Walk(t, seconds);
                        }
                        break;
                    default:
                        Walk(t, seconds);
                        break;
                }
            }

            /// <summary>How far a plant is up: 0 for down, 1 for up.</summary>
            private static double PlantUp(Thing t)
            {
                double phase = t.Clock - PlantDown;
                if (phase < 0) return 0;
                if (phase < PlantRise) return phase / PlantRise;
                phase -= PlantRise;
                if (phase < PlantStay) return 1;
                return Math.Max(0, 1 - (phase - PlantStay) / PlantRise);
            }

            /// <summary>The rows above the ground of the lowest row of a bird: it goes up and down a little as it flies.</summary>
            private static double BirdY(Thing t)
            {
                return t.State == StateAway ? t.Y : t.Y + BobRows * Math.Sin(t.Clock * 2 * Math.PI / BobSeconds);
            }

            // ---------------------------------------------------------------- DC01

            /// <summary>
            /// Where DC01 stands while it throws: its left side, in cells ahead of the right side of the
            /// runner. Near the right edge of a screen of eighty columns, and no further ahead on a wider one.
            /// </summary>
            private double Station { get { return Math.Min(BossFar, _width - _runnerX - RunnerWidth - BossWide - 3); } }

            /// <summary>The column of the screen of the left side of DC01.</summary>
            private int BossX { get { return _runnerX + RunnerWidth + (int)Math.Floor(_bossAt); } }

            /// <summary>Whether something of the course is still ahead of the runner, or with it.</summary>
            private bool Ahead()
            {
                double left = _distance + _runnerX - 2;
                foreach (var t in _things)
                {
                    if (!t.Gone && t.Kind != KindSpring && t.X + t.Width > left) return true;
                }
                return false;
            }

            /// <summary>DC01 comes on screen: the route is on the ground from here, and every bridge ends at the edge.</summary>
            private void StartBoss(double edge)
            {
                // A bridge of the route that only just began goes on for a few cells, for the coin of its step.
                if (_open != null) ClosePlatform(Ending(Math.Max(edge, _open.From + 16), 0), 0);
                Level(0);
                foreach (var p in _platforms)
                {
                    if (p.To > edge && !p.Route) p.To = Math.Max(p.From, edge);
                }
                _arcX = double.NaN;
                _boss = BossArrives;
                _bossAt = Station + BossWide + 12;
                Note(LastAhead, "DC01", "the last domain controller. Land on it when it charges.", 0, 1, false);
            }

            /// <summary>
            /// What DC01 does. It comes on screen and waits until the course before it is played. Then it
            /// throws a few things, one after the other where each leaves the time for the next; when
            /// they are gone it warns, and charges at the runner: on a runner that comes down on it it
            /// takes a stomp, and one that is in its way it hits. Either way it goes back to where it
            /// stood, and starts again: with every stomp it took a little faster, and from the second
            /// one on with one more thing to throw, through the air. After the last stomp it falls.
            /// </summary>
            private void MoveBoss(double seconds)
            {
                switch (_boss)
                {
                    case BossArrives:
                        _bossAt = Math.Max(Station, _bossAt - BossIn * seconds);
                        if (_bossAt <= Station && !Ahead()) NextRound(0.6);
                        break;
                    case BossThrows:
                        _bossAt = Station;
                        _bossClock -= seconds;
                        if (_bossShots > 0)
                        {
                            if (_bossClock > 0) break;
                            if (Throw())
                            {
                                _bossShots--;
                                _bossClock = BossThrowSeconds * (1 - BossThrowSooner * BossHits) * (0.8 + 0.4 * _random.NextDouble());
                            }
                            else
                            {
                                _bossClock = 0.2;
                            }
                        }
                        else if (!Ahead())
                        {
                            _boss = BossWarns;
                            _bossClock = BossWarnSeconds;
                            _tones.Add(ToneSnap);
                        }
                        break;
                    case BossWarns:
                        _bossClock -= seconds;
                        if (_bossClock <= 0) _boss = BossCharges;
                        break;
                    case BossCharges:
                        _bossAt -= ChargeSpeed * seconds;
                        // Past a runner that it could not touch.
                        if (_bossAt < -(RunnerWidth + BossWide + 6)) _boss = BossBack;
                        break;
                    case BossBack:
                        _bossAt += BossOut * seconds;
                        if (_bossAt >= Station) NextRound(0.8);
                        break;
                    case BossFalls:
                        _bossClock -= seconds;
                        if (_bossClock <= 0)
                        {
                            _boss = BossGone;
                            BossGoneFor = 0;
                        }
                        break;
                    case BossGone:
                        if (BossGoneFor >= 0) BossGoneFor += seconds;
                        break;
                }
            }

            /// <summary>How fast DC01 charges: faster with every stomp it took.</summary>
            private double ChargeSpeed { get { return BossCharge + BossChargeMore * BossHits; } }

            private void NextRound(double wait)
            {
                _boss = BossThrows;
                _bossAt = Station;
                _bossClock = wait;
                _bossShots = 2 + _random.Next(2) + (BossHits >= BossMoreFrom ? 1 : 0);
                _bossAir = BossHits >= BossMoreFrom;
            }

            /// <summary>
            /// DC01 throws something with a name of the directory: a packet along the ground, to jump on
            /// or over, or one through the air over the head of the runner, which a jump under it runs
            /// into. False when it would not leave the runner the time.
            /// </summary>
            private bool Throw()
            {
                double x = Front + _bossAt - 4;
                string name = GameDirectory[_random.Next(GameDirectory.Length)];
                if (_bossAir || _random.Next(100) < 35)
                {
                    double y = LevelRows + 1;
                    if (!Fits(KindBird, x, y)) return false;
                    _things.Add(new Thing { Kind = KindBird, X = x, Y = y, Base = (int)y, Width = GameKindWidth[KindPacket], Height = 2, Speed = BirdSpeed, Id = name, Title = "thrown by DC01", Named = true, Shot = true });
                    _bossAir = false;
                    return true;
                }
                if (!Fits(KindPacket, x, 0)) return false;
                _things.Add(new Thing { Kind = KindPacket, X = x, Width = GameKindWidth[KindPacket], Height = GameKindRows[KindPacket], Speed = PacketSpeed, Id = name, Title = "thrown by DC01", Named = true, Shot = true });
                return true;
            }

            // ---------------------------------------------------------------- what the runner touches

            /// <summary>
            /// What the runner touches. A coin is collected. A creature or a bird is stomped when the
            /// runner comes down on it, and hits the runner otherwise. A plant that is up hits. So does
            /// DC01 when it charges, unless the runner comes down on it. A runner that was hit a moment
            /// ago touches nothing.
            /// </summary>
            private void Touch()
            {
                double left = _distance + _runnerX;
                if (_hitClock > 0)
                {
                    foreach (var t in _things)
                    {
                        if (t.Kind != KindCoin && t.X < left + RunnerWidth && t.X + t.Width > left) t.Through = true;
                    }
                    return;
                }
                foreach (var t in _things)
                {
                    if (t.Gone || t.Through || t.Kind == KindSpring || t.X >= left + RunnerWidth || t.X + t.Width <= left) continue;
                    if (t.Kind == KindCoin)
                    {
                        if (_y < t.Base + t.Height + CoinReach && _y + RunnerRows > t.Base) Collect(t);
                        continue;
                    }
                    double low = t.Base;
                    double top = t.Base + t.Height;
                    // A creature is stomped by feet that come down on its top row; a bird by feet that
                    // come down anywhere on it.
                    double deep = 1.25;
                    if (t.Kind == KindPlant)
                    {
                        // What hits is the middle of the plant, and the middle of the runner.
                        double up = PlantUp(t);
                        if (up < 0.5 || t.X + 1 >= left + RunnerWidth - 1 || t.X + t.Width - 1 <= left + 1) continue;
                        top = t.Base + 1 + up - PlantSlack;
                    }
                    else if (t.Kind == KindBird)
                    {
                        if (t.State == StateAway) continue;
                        low = BirdY(t);
                        top = low + t.Height;
                        deep = t.Height;
                    }
                    if (_y >= top || _y + RunnerRows <= low + 0.25) continue;
                    if (t.Kind != KindPlant && _vy < 0 && _y >= top - deep)
                    {
                        Stomp(t, top);
                        continue;
                    }
                    bool bitten = (t.Kind == KindBiter || t.Kind == KindBrute) && (t.State == StateLunge || t.State == StateRest);
                    Hit(bitten ? LastBite : LastHit, t.Id, t.Title, Math.Max(1, t.Count), !t.Test);
                    return;
                }
                if (_boss != BossCharges) return;
                double boss = Front + _bossAt;
                if (boss >= left + RunnerWidth || boss + BossWide <= left || _y >= BossRows) return;
                if (_vy < 0 && _y >= BossRows - 1.25)
                {
                    StompBoss();
                    return;
                }
                Hit(LastHit, "DC01", "the last domain controller", 1, false);
                if (!Over) _boss = BossBack;
            }

            private void Hit(int kind, string id, string title, int count, bool free)
            {
                Hits++;
                Streak = 0;
                _form = 0;
                _hitClock = HitSeconds;
                Lives--;
                Note(kind, id, title, 0, count, free);
                if (Lives > 0)
                {
                    _tones.Add(ToneHit);
                    return;
                }
                // The last heart: the game is over.
                Over = true;
                OverFor = 0;
                _earlyUntil = -10;
                _tones.Add(ToneDeath);
            }

            /// <summary>One more, or several, in the streak and in the form of the runner: every ten of a streak is heard, and every twenty-five gives a heart back.</summary>
            private void Tally(int count)
            {
                _form = Math.Min(FormFull, _form + count);
                int streak = Streak;
                Streak += count;
                BestStreak = Math.Max(BestStreak, Streak);
                if (Streak / StreakMilestone > streak / StreakMilestone) _tones.Add(ToneStreak);
                if (Streak / HeartStreak > streak / HeartStreak && Lives < Hearts)
                {
                    Lives++;
                    _tones.Add(ToneHeart);
                    _popups.Add(new Popup { X = _distance + _runnerX, Y = _y + RunnerRows + 1, Heart = true });
                }
            }

            /// <summary>
            /// The points of a pick-up: its share of a test in thousandths, six tenths at once and four by
            /// the form of the runner. What the dice put on the course is worth nothing, and counts for
            /// the streak and the form as one: its name rises from where it was, with a no before it.
            /// </summary>
            private int Earn(Thing t, int full)
            {
                int before = Score;
                _units += (long)t.Count * (full * 6 / 10 + full * 4 / 10 * _form / FormFull);
                int points = Score - before;
                double y = t.Kind == KindBird ? BirdY(t) + t.Height + 1 : t.Base + t.Height + 1;
                if (full > 0) _popups.Add(new Popup { X = t.X, Y = y, Text = "+" + points.ToString(CultureInfo.InvariantCulture) });
                else if (t.Named && !t.Test) _popups.Add(new Popup { X = t.X - 2, Y = y, Text = "no " + t.Id });
                Tally(Math.Max(1, t.Count));
                return points;
            }

            private void Collect(Thing t)
            {
                t.Gone = true;
                t.GoneFor = GoneSeconds;
                Coins += t.Count;
                Note(LastCoin, t.Id, t.Title, Earn(t, 1000), t.Count, false);
                _tones.Add(ToneCoin);
            }

            private void Stomp(Thing t, double top)
            {
                t.Gone = true;
                Stomps += Math.Max(1, t.Count);
                // Only a failed test is worth points.
                bool test = t.Count > 0;
                Note(LastStomp, t.Id, t.Title, Earn(t, test ? 500 : 0), Math.Max(1, t.Count), !test);
                _tones.Add(ToneStomp);
                Bounce(top);
            }

            /// <summary>The runner bounces off what it came down on, and has its second jump again.</summary>
            private void Bounce(double top)
            {
                _y = top;
                _vy = BounceSpeed;
                _supported = false;
                _jumps = 1;
            }

            /// <summary>A stomp on DC01: a quarter of its tenth of the score. After the last one it falls, and the sound of that is its own.</summary>
            private void StompBoss()
            {
                int before = Score;
                BossHits++;
                Stomps++;
                int points = Score - before;
                _popups.Add(new Popup { X = Front + _bossAt, Y = BossRows + 2, Text = "+" + points.ToString(CultureInfo.InvariantCulture) });
                Tally(1);
                Bounce(BossRows);
                if (BossHits >= BossHp)
                {
                    _boss = BossFalls;
                    _bossClock = BossFallSeconds;
                    _tones.Add(ToneDown);
                    Note(LastStomp, "DC01", "decommissioned", points, 1, false);
                    return;
                }
                _boss = BossBack;
                _tones.Add(ToneStomp);
                Note(LastStomp, "DC01", BossHits.ToString(CultureInfo.InvariantCulture) + " of " + BossHp.ToString(CultureInfo.InvariantCulture), points, 1, false);
            }

            private void Note(int kind, string id, string title, int points, int count, bool free)
            {
                LastKind = kind;
                LastId = id;
                LastTitle = title;
                LastPoints = points;
                LastCount = count;
                LastFree = free;
            }

            // ---------------------------------------------------------------- drawing

            /// <summary>
            /// Draws the playfield over what the canvas has: the skyline far behind, the clouds, the
            /// ground, the bridges, what is on the course, DC01, and the runner; and then the names. The
            /// skyline is a colour behind the cells, so it is drawn only where there is colour.
            /// </summary>
            public void Draw(Canvas canvas, bool unicode, bool skyline, bool trueColour)
            {
                int view = (int)Math.Floor(_distance);
                if (skyline)
                {
                    // Racks on the horizon, which go by at a quarter of the speed of the ground. None is
                    // as high as the counter of the run is low.
                    int far = (int)Math.Floor(_distance / 4);
                    int most = Math.Max(2, Math.Min(8, _ground - 12));
                    for (int x = 0; x < _width; x++)
                    {
                        int rack = (far + x) / 13;
                        int wide = 6 + (int)(WallNoise(rack, 21, 5) * 6);
                        if ((far + x) % 13 >= wide) continue;
                        int high = 2 + (int)(WallNoise(rack, 22, 5) * (most - 1));
                        for (int row = 1; row <= high; row++) canvas.Back(x, _ground - row);
                    }
                }
                // The clouds go by at a seventh of the speed of the ground.
                var cloud = unicode ? GameCloud : GameCloudAscii;
                int span = _width + 40;
                for (int i = 0; i < _cloudCount * 2; i += 2)
                {
                    int x = (int)(((_clouds[i] - _distance / 7) % span + span) % span) - 12;
                    canvas.Under(x, (int)_clouds[i + 1], cloud[0], GsScenery);
                    canvas.Under(x, (int)_clouds[i + 1] + 1, cloud[1], GsScenery);
                }
                for (int x = 0; x < _width; x++)
                {
                    canvas.Put(x, _ground, unicode ? '▔' : '-', GsGround);
                    if ((view + x) % 9 == 0) canvas.Put(x, _ground + 1, unicode ? '·' : '.', GsDust);
                }
                _taken.Clear();
                foreach (var p in _platforms)
                {
                    int from = Math.Max(0, (int)Math.Floor(p.From) - view);
                    int to = p.To >= double.MaxValue ? _width : Math.Min(_width, (int)Math.Floor(p.To) - view);
                    for (int x = from; x < to; x++) canvas.Put(x, _ground - p.Surface, unicode ? '▀' : '=', GsPlatform);
                    // No coin has its name in a bridge: that would look like a gap in it.
                    if (from < to) Solid(_ground - p.Surface, 1, from, to - from);
                }
                bool feet = ((int)(_time * 4) & 1) == 0;
                _labels.Clear();
                foreach (var t in _things)
                {
                    int x = (int)Math.Floor(t.X) - view;
                    int row = _ground - t.Base - t.Height;
                    string[] sprite;
                    byte style;
                    switch (t.Kind)
                    {
                        case KindCoin:
                            if (t.Gone) continue;
                            if (t.Count == 1)
                            {
                                // It turns: its face most of the time, its edge for a moment.
                                double turn = _time * 1.5 + t.X * 0.03;
                                sprite = (unicode ? GameCoin : GameCoinAscii)[turn - Math.Floor(turn) < 0.75 ? 0 : 1];
                            }
                            else
                            {
                                sprite = unicode ? GameCoins : GameCoinsAscii;
                            }
                            canvas.Text(x, row, sprite[0], GsCoin);
                            canvas.Text(x, row + 1, sprite[1], GsCoin);
                            // Its name is the ID of its test, or of the first of its tests and how many more.
                            string id = FitMiddle(t.Id, 15, unicode);
                            string more = t.Count > 1 ? (id.Length > 0 ? " +" : "+") + (t.Count - 1).ToString(CultureInfo.InvariantCulture) : string.Empty;
                            _labels.Add(new Label { X = x + t.Width / 2, Row = row - 1, Text = id + more, Style = GsCoinName, Short = t.Count > 1 ? (unicode ? "×" : "x") + t.Count.ToString(CultureInfo.InvariantCulture) : string.Empty });
                            continue;
                        case KindSpring:
                            canvas.Text(x, row, unicode ? GameSpring : GameSpringAscii, GsSpring);
                            continue;
                        case KindPlant:
                            double up = PlantUp(t);
                            sprite = (unicode ? GamePlant : GamePlantAscii)[up <= 0 ? 0 : (up < 1 ? 1 : (((int)(t.Clock * 4) & 1) == 0 ? 2 : 3))];
                            canvas.Text(x, row, sprite[0], t.Test ? GsError : GsPlant);
                            canvas.Text(x, row + 1, sprite[1], GsPot);
                            break;
                        case KindBird:
                            row = _ground - (int)Math.Round(BirdY(t)) - t.Height;
                            style = t.Shot ? GsBoss : (t.Test ? GsInvestigate : GsBird);
                            if (t.Gone)
                            {
                                // What is left of a bird that was stomped.
                                canvas.Text(x, row + 1, unicode ? " ▘▗▝ " : " '.' ", style);
                                continue;
                            }
                            sprite = t.Shot ? (unicode ? GamePacket : GamePacketAscii) : (unicode ? GameBird : GameBirdAscii)[((int)(t.Clock * 5) & 1)];
                            canvas.Text(x, row, sprite[0], style);
                            canvas.Text(x, row + 1, sprite[1], style);
                            break;
                        default:
                            style = t.Kind == KindWalker ? GsWalker : (t.Kind == KindAttack ? GsAttack : (t.Kind == KindPacket ? GsBoss : GameSeverityStyle[t.Severity]));
                            if (t.Gone)
                            {
                                // What is left of a creature that was stomped.
                                string flat = t.Width < 5 ? (unicode ? "▁▃▁" : "_._") : (unicode ? "▁▂" + new string('▃', t.Width - 4) + "▂▁" : "_." + new string('-', t.Width - 4) + "._");
                                canvas.Text(x, _ground - t.Base - 1, flat, style);
                                continue;
                            }
                            sprite = t.Kind == KindPacket ? (unicode ? GamePacket : GamePacketAscii) : Frames(t, unicode)[t.State == StateOpen || t.State == StateLunge ? 2 : (feet ? 0 : 1)];
                            for (int r = 0; r < sprite.Length; r++) canvas.Text(x, row + r, sprite[r], style);
                            break;
                    }
                    Solid(row, sprite.Length, x, t.Width);
                    if (!t.Named) continue;
                    string label = FitMiddle(t.Id, 17, unicode);
                    if (t.Count > 1) label += " +" + (t.Count - 1).ToString(CultureInfo.InvariantCulture);
                    int middle = x + t.Width / 2;
                    // The name of what DC01 just threw is beside DC01, not on it.
                    if (t.Shot && _boss != BossNone && _boss != BossGone) middle = Math.Min(middle, BossX - 1 - (label.Length - label.Length / 2));
                    _labels.Add(new Label { X = middle, Row = row - 1, Text = label, Style = GsLabel });
                }
                DrawBoss(canvas, unicode);
                DrawLabels(canvas);
                foreach (var popup in _popups)
                {
                    int x = (int)Math.Floor(popup.X) - view;
                    int y = _ground - 1 - (int)(popup.Y + popup.Age * 4);
                    if (popup.Heart) canvas.Text(x, y, unicode ? "♥ +1" : "+1 heart", GsHeart);
                    else canvas.Text(x, y, popup.Text, GsPoints);
                }
                // The runner. One that was hit stumbles: its head goes down and up until it can be hit again.
                var runner = unicode ? GameRunner : GameRunnerAscii;
                int top = _ground - RunnerRows - (int)Math.Round(_y);
                if (Over && OverFor >= OverSeconds / 2)
                {
                    // The game is over: the runner is down.
                    canvas.Text(_runnerX, top + 2, unicode ? "▁▂▃▂▁" : "_.-._", GsRunner);
                    return;
                }
                bool down = Over || (_hitClock > 0 && ((int)(_time * 8) & 1) == 1);
                byte red = trueColour ? GsRunnerTrue : GsRunner;
                canvas.Text(_runnerX, top, runner[down ? 5 : 0], red);
                canvas.Text(_runnerX, top + 1, runner[1], red);
                canvas.Text(_runnerX, top + 2, runner[!_supported ? 4 : (((int)(_distance / 3) & 1) == 0 ? 2 : 3)], red);
            }

            /// <summary>
            /// The names, each in the middle over what it is the name of. The names of what is in the way
            /// come first. The name of a coin is drawn where it is in the way of no other name, of no
            /// bridge and of nothing that walks or flies: where coins are close to one another, as many
            /// have their name as there is room for, and a coin that a creature walks over has none. A
            /// coin of several tests that has no room for its name says how many it is. A name covers
            /// what is behind it, the space between its words and a cell at each of its ends as well,
            /// so that it reads as a name where the counter of the run is behind it.
            /// </summary>
            private void DrawLabels(Canvas canvas)
            {
                for (int pass = 0; pass < 2; pass++)
                {
                    foreach (var label in _labels)
                    {
                        if ((label.Style == GsCoinName) != (pass == 1)) continue;
                        string text = label.Text;
                        bool coin = pass == 1;
                        if (coin && (text.Length == 0 || !Free(label.Row, label.X - text.Length / 2, text.Length)))
                        {
                            text = label.Short;
                            if (text.Length == 0 || !Free(label.Row, label.X - text.Length / 2, text.Length)) continue;
                        }
                        int from = label.X - text.Length / 2;
                        canvas.Cover(from - 1, label.Row, " " + text + " ", coin && text == label.Short ? GsCoin : label.Style);
                        _taken.Add(label.Row);
                        _taken.Add(from);
                        _taken.Add(from + text.Length);
                    }
                }
            }

            /// <summary>Marks the cells of a bridge or of something that is in the way, so that no coin has its name over them.</summary>
            private void Solid(int row, int rows, int from, int width)
            {
                for (int r = 0; r < rows; r++)
                {
                    _taken.Add(row + r);
                    _taken.Add(from);
                    _taken.Add(from + width);
                }
            }

            /// <summary>Whether the name of a coin has room in a row: no other name, no bridge and nothing in the way within a cell of it.</summary>
            private bool Free(int row, int from, int length)
            {
                for (int i = 0; i < _taken.Count; i += 3)
                {
                    if (_taken[i] == row && from < _taken[i + 2] + 2 && _taken[i + 1] < from + length + 2) return false;
                }
                return true;
            }

            /// <summary>
            /// DC01: a rack, its name and the stomps it still takes over it. Its lights are green, and
            /// red when it warns and charges. When it falls it sinks into the ground, row by row.
            /// </summary>
            private void DrawBoss(Canvas canvas, bool unicode)
            {
                if (_boss == BossNone || _boss == BossGone) return;
                var sprite = unicode ? GameBoss : GameBossAscii;
                int x = BossX;
                int sunk = _boss == BossFalls ? (int)((1 - _bossClock / BossFallSeconds) * (BossRows + 1)) : 0;
                // As it falls it shakes.
                if (_boss == BossFalls && ((int)(_bossClock * 16) & 1) == 1) x++;
                bool alarm = _boss == BossWarns || _boss == BossCharges;
                bool lit = _boss != BossFalls && (!alarm || ((int)(_time * 8) & 1) == 0);
                for (int r = 0; r + sunk < BossRows; r++)
                {
                    int row = _ground - BossRows + r + sunk;
                    canvas.Text(x, row, sprite[r], GsBoss);
                    if ((r == 1 || r == 3) && lit) canvas.Put(x + 1, row, sprite[r][1], alarm ? GsBossAlarm : GsBossLight);
                }
                Solid(_ground - BossRows - 1, BossRows + 1, x, BossWide);
                if (_boss == BossFalls) return;
                string left = new string(unicode ? '■' : '#', BossHp - BossHits) + new string(unicode ? '□' : '-', BossHits);
                string name = "DC01 " + left + (_boss == BossWarns ? " !!" : string.Empty);
                canvas.Text(x + BossWide / 2 - 4, _ground - BossRows - 1, name, alarm ? GsBossAlarm : GsCardText);
            }

            private static string[][] Frames(Thing t, bool unicode)
            {
                bool wide = t.Width > 7;
                switch (t.Kind)
                {
                    case KindWalker: return unicode ? GameWalker : GameWalkerAscii;
                    case KindAttack: return unicode ? GameAttack : GameAttackAscii;
                    case KindBrute: return wide ? (unicode ? GameBrutes : GameBrutesAscii) : (unicode ? GameBrute : GameBruteAscii);
                    case KindGiant: return wide ? (unicode ? GameGiants : GameGiantsAscii) : (unicode ? GameGiant : GameGiantAscii);
                    default: return wide ? (unicode ? GameBiters : GameBitersAscii) : (unicode ? GameBiter : GameBiterAscii);
                }
            }

            /// <summary>An ID in a width: one that is too long is cut in its middle, as in the lists of the dashboard.</summary>
            private static string FitMiddle(string id, int width, bool unicode)
            {
                if (id.Length <= width) return id;
                int tail = (width - 1) / 2;
                return id.Substring(0, width - 1 - tail) + (unicode ? "…" : ".") + id.Substring(id.Length - tail);
            }
        }

        private readonly List<RunResult> _runResults = new List<RunResult>();
        private readonly Canvas _gameCanvas = new Canvas();
        private Runner _game;
        private MtConsoleGameResult _gameTop;
        private int _gameCount;
        private bool _gameShown;
        private bool _gameEnded;
        private bool _gameBroken;
        private int _gameFed;
        // The results that the run had when the game last stood still, or was started.
        private int _gameSince;
        private int _gameBossRule;
        private int _gameBest;
        private string _gameBestDate;
        private bool _gameBestRead;
        private bool _gameNewBest;
        private Line _gameKeys;
        private string _gameKeysFor;

        /// <summary>The seed of the dice of the game, for tests. 0 for a different game every time.</summary>
        public int GameSeed { get; set; }

        /// <summary>
        /// Only the results of the run are on the course: nothing that the dice add, a route that goes up
        /// for passed tests only, and no skyline behind it. For the tests of the course itself.
        /// </summary>
        public bool GameCourseOnly { get; set; }

        /// <summary>
        /// The file that keeps the best score of this user: one line, the score and the day. Null for none.
        /// It is read when the game is first put on screen, and written by SaveGameBest.
        /// </summary>
        public string GameBestPath { get; set; }

        /// <summary>The game is on screen, in place of the dashboard.</summary>
        public bool IsGameShown { get { lock (_gate) return _gameShown; } }

        /// <summary>The score of the best game of this run so far, 0 to 10,000, or null when the game was not played.</summary>
        public int? GameScore
        {
            get { lock (_gate) return _game == null ? (int?)null : GameBestOfRun().Score; }
        }

        /// <summary>
        /// How the game of this run went so far, or null when the game was not played. When a game was
        /// over and another was started, it is the one with the highest score.
        /// </summary>
        public MtConsoleGameResult GameResult
        {
            get { lock (_gate) return _game == null ? null : GameBestOfRun(); }
        }

        /// <summary>What is on the course of the game, a line each: see Runner.Describe. Null when the game is not played. For tests.</summary>
        public string[] GetGameCourse()
        {
            lock (_gate)
            {
                if (_game == null) return null;
                var lines = new List<string>();
                _game.Describe(lines);
                return lines.ToArray();
            }
        }

        /// <summary>
        /// Writes the score of this run to the file of the best score when it is higher than what is
        /// there, and says whether it did. It is for after the run. A file that cannot be read counts as no
        /// best score, and one that cannot be written is left alone: nothing here throws.
        /// </summary>
        public bool SaveGameBest()
        {
            string path;
            int score;
            lock (_gate)
            {
                if (_game == null || string.IsNullOrEmpty(GameBestPath)) return false;
                path = GameBestPath;
                score = GameBestOfRun().Score;
            }
            try
            {
                // Read again: another run of this user may have written a better score since this game began.
                ReadGameBest(path);
                lock (_gate)
                {
                    if (score <= 0 || score <= _gameBest) return false;
                }
                string day = DateTime.Now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                string folder = Path.GetDirectoryName(path);
                if (!string.IsNullOrEmpty(folder)) Directory.CreateDirectory(folder);
                File.WriteAllText(path, score.ToString(CultureInfo.InvariantCulture) + " " + day + "\n");
                lock (_gate)
                {
                    _gameBest = score;
                    _gameBestDate = day;
                    _gameNewBest = true;
                }
                return true;
            }
            catch (Exception)
            {
                // The score is not kept, then.
                return false;
            }
        }

        /// <summary>Reads the file of the best score: "8150 2026-10-13". Anything else in it, or no file, is no best score.</summary>
        private void ReadGameBest(string path)
        {
            int best = 0;
            string day = null;
            try
            {
                var file = new FileInfo(path);
                if (file.Exists && file.Length <= 64)
                {
                    string[] parts = File.ReadAllText(path).Trim().Split(' ');
                    int score = 0;
                    DateTime when;
                    bool ok = parts.Length == 2 && int.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out score) && score > 0 && score <= GameFullScore &&
                        DateTime.TryParseExact(parts[1], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out when);
                    if (ok)
                    {
                        best = score;
                        day = parts[1];
                    }
                }
            }
            catch (Exception)
            {
                // A file that cannot be read is no best score.
            }
            lock (_gate)
            {
                _gameBest = best;
                _gameBestDate = day;
                _gameBestRead = true;
            }
        }

        // ------------------------------------------------------------------ the game and the run (callers hold _gate)

        /// <summary>The game that is played, in numbers.</summary>
        private MtConsoleGameResult GameNow()
        {
            return new MtConsoleGameResult
            {
                Score = _game.Score, Games = _gameCount + 1, Tests = _game.Total, Coins = _game.Coins, Stomps = _game.Stomps, Hits = _game.Hits,
                BestStreak = _game.BestStreak, Best = _gameBest, BestDate = _gameBestDate, NewBest = _gameNewBest, Boss = _game.HasBoss && _game.BossCame, BossDown = _game.BossDown
            };
        }

        /// <summary>The best game of the run: the one that is played, or one that was over before it with a higher score.</summary>
        private MtConsoleGameResult GameBestOfRun()
        {
            var now = GameNow();
            if (_gameTop == null || now.Score >= _gameTop.Score) return now;
            return new MtConsoleGameResult
            {
                Score = _gameTop.Score, Games = now.Games, Tests = now.Tests, Coins = _gameTop.Coins, Stomps = _gameTop.Stomps, Hits = _gameTop.Hits,
                BestStreak = _gameTop.BestStreak, Best = now.Best, BestDate = now.BestDate, NewBest = now.NewBest, Boss = _gameTop.Boss, BossDown = _gameTop.BossDown
            };
        }

        /// <summary>A game with the dice of this run.</summary>
        private Runner NewGame()
        {
            var game = new Runner(GameSeed != 0 ? new Random(GameSeed + _gameCount) : new Random());
            game.Extras = !GameCourseOnly;
            return game;
        }

        /// <summary>
        /// Another game, after one that is over: from the point the run has reached, with no points, and
        /// with the whole run still what the score is a share of. What the game that is over had not put
        /// on its course yet is for the new one.
        /// </summary>
        private void PlayGameAgain()
        {
            _gameTop = GameBestOfRun();
            _gameFed = Math.Max(0, _gameFed - _game.Waiting);
            _gameCount++;
            _game = NewGame();
            _gameSince = _runResults.Count;
            _gameClock.Restart();
            _gameLast = 0;
        }

        /// <summary>A test finished: the entry that a game needs. This is all the game costs a run that does not play it.</summary>
        private void RecordGameResult(string id, string title, string result, string severity)
        {
            if (!_fullScreen) return;
            byte kind = ResultOther;
            if (result == "Passed")
            {
                kind = ResultPassed;
            }
            else if (result == "Failed")
            {
                int index = Array.IndexOf(SeverityOrder, Normalise(severity));
                kind = (byte)(ResultFailed + (index >= 0 ? index : GameOtherSeverity));
            }
            else if (result == "Error")
            {
                kind = ResultError;
            }
            else if (result == "Investigate")
            {
                kind = ResultInvestigate;
            }
            _runResults.Add(new RunResult { Kind = kind, Id = id, Title = title });
            // What comes while the game stands still is not what the end of the run kept from the runner.
            if (_game != null && !GameMoving()) _gameSince = _runResults.Count;
        }

        /// <summary>Whether the game is on screen and the runner is running: not over, not paused, with nothing in front of it.</summary>
        private bool GameMoving()
        {
            return _game != null && _gameShown && !_gameEnded && !_gameHelp && _gameWall == null && !_gameSplash && !_game.Paused && !_game.Over;
        }

        /// <summary>Gives the game the results of the run that it does not have yet, and the number of tests of the run.</summary>
        private void FeedGame()
        {
            for (; _gameFed < _runResults.Count; _gameFed++)
            {
                var result = _runResults[_gameFed];
                _game.Enqueue(result.Kind, result.Id, result.Title);
            }
            _game.Total = _total;
            RuleGameBoss();
        }

        /// <summary>Tells the game whether DC01 is due, and whether the run turned out too short for it.</summary>
        private void RuleGameBoss()
        {
            _game.BossDue = GameBossDue();
            _game.NoBoss = _gameBossRule == GameBossShort;
        }

        /// <summary>
        /// Whether it is time for DC01: when nine tenths of the tests of the run are done, or, from the
        /// middle of the run on, when what is left takes no more than a minute by the measure the
        /// dashboard has for that (the time the tests took so far, for each test that is left). So it
        /// comes with a minute to go, or with more in a run of more than ten minutes, and there is time
        /// for the fight before the tests stop. Once it is due it stays due.
        ///
        /// A run whose tests take less than two minutes by that measure has no room for the fight and
        /// for the results that wait while it goes on, and no DC01. That is said once, at the moment
        /// DC01 would be due, when half of the run or more is known: until then the score counts the
        /// tests as nine tenths, and from then on, in such a run, as all of it. It is said of the run,
        /// not of what is left of it: in a long run DC01 comes at once for a game that is opened late.
        /// </summary>
        private bool GameBossDue()
        {
            if (_gameBossRule == GameBossShort) return false;
            if (_gameBossRule == GameBossIsDue) return true;
            int done = FinishedCount();
            if (_total < Runner.BossFrom || done < 5) return false;
            // Without the timer (tests) time moves only when it is advanced, so a slow machine decides nothing.
            double seconds = (RefreshIntervalMs > 0 ? CurrentPhaseClock().Elapsed.TotalSeconds : 0) + _keyClockAdvance / 1000.0;
            double left = seconds / done * (_total - done);
            if ((long)done * 10 < (long)_total * 9 && (done * 2 < _total || left > GameBossSeconds)) return false;
            _gameBossRule = seconds + left < GameBossRunSeconds ? GameBossShort : GameBossIsDue;
            return _gameBossRule == GameBossIsDue;
        }

        // ------------------------------------------------------------------ the screen of the game (callers hold _gate)

        /// <summary>
        /// The whole screen while the game is on it: the HUD and the progress bar of the run, the playfield,
        /// the ticker and the keys.
        /// </summary>
        private List<Line> BuildGameScreen(int width, int height, bool ansi)
        {
            int max = Math.Max(1, width - 1);
            int field = height - GameFrameRows(width, height);
            _game.Layout(max, field);
            FeedGame();
            var canvas = _gameCanvas;
            canvas.Reset(max, field);
            // The run's own counter behind everything, then the game, then a card when the game stands
            // still. When DC01 is gone its words are in the sky for some seconds, where the counter is after them.
            if (_game.BossGoneFor >= 0 && _game.BossGoneFor < GameWordsSeconds) DrawGameWords(canvas, BossLines);
            else DrawGameBackdrop(canvas, ansi);
            _game.Draw(canvas, Unicode, ansi && !GameCourseOnly, TrueColor);
            DrawGameCard(canvas);

            var lines = new List<Line>(height);
            if (GameHudRows(width, height) > 1) lines.AddRange(GameBand(max, ansi));
            else lines.Add(GameHud(max, ansi));
            // The progress bar of the run is the track, and its end is the finish.
            const string finish = " FINISH";
            var bar = new LineBuilder(ansi).Add(" ");
            int cells = Math.Max(1, max - 1 - finish.Length);
            int filled = _total > 0 ? (int)Math.Min(cells, (long)cells * FinishedCount() / _total) : 0;
            bar.Add(new string(Unicode ? '━' : '#', filled), "38;5;208").Add(new string(Unicode ? '─' : '-', cells - filled), "38;5;238").Add(finish, "2");
            lines.Add(bar.Build());
            int top = lines.Count;
            for (int y = 0; y < field; y++) lines.Add(GameRow(canvas, y, ansi));
            lines.Add(GameTicker(max, ansi));
            lines.Add(GameKeys(max, ansi));
            _canvasTop = top;
            // The first time in a run the dashboard is a wall in front of all that, which breaks.
            var wall = _gameWall;
            if (wall == null || _gameEnded || wall.Wall.Width != max || wall.Wall.Height != height) return lines;
            try
            {
                var broken = BuildWallScreen(lines, max, height, ansi);
                // The playfield is behind the wall: its rows are not on the screen as they are.
                _canvasTop = -1;
                return broken;
            }
            catch (Exception)
            {
                EndGameWall();
                return lines;
            }
        }

        /// <summary>
        /// One row of the playfield as a line: a colour sequence only where the style changes, or where
        /// the skyline behind the cells begins or ends.
        /// </summary>
        private static Line GameRow(Canvas canvas, int y, bool ansi)
        {
            int from = y * canvas.Width;
            int end = canvas.Width;
            while (end > 0 && canvas.Cells[from + end - 1] == ' ' && !(ansi && canvas.Behind[from + end - 1])) end--;
            if (end == 0) return new Line { Text = string.Empty, Plain = string.Empty };
            string plain = new string(canvas.Cells, from, end);
            if (!ansi) return new Line { Text = plain.TrimEnd(' '), Plain = plain.TrimEnd(' ') };
            var text = new StringBuilder(end + 64);
            byte style = GsNone;
            bool behind = false;
            for (int x = 0; x < end; x++)
            {
                // A space has nothing to colour: it does not change the style.
                byte want = canvas.Cells[from + x] == ' ' ? style : canvas.Styles[from + x];
                bool back = canvas.Behind[from + x];
                if (want != style || back != behind)
                {
                    text.Append(Esc).Append('0');
                    if (want != GsNone) text.Append(';').Append(GameSgr[want]);
                    if (back) text.Append(';').Append(GameSkyline);
                    text.Append('m');
                    style = want;
                    behind = back;
                }
                text.Append(canvas.Cells[from + x]);
            }
            if (style != GsNone || behind) text.Append(Esc).Append("0m");
            return new Line { Text = text.ToString(), Plain = plain };
        }

        private static string GameNumber(int number) { return number.ToString("#,0", CultureInfo.InvariantCulture); }

        /// <summary>
        /// The first row: the name, the hearts, the score, the streak and the best score so far, and at
        /// the right the run itself, with the progress text and the counts of the dashboard. In fewer
        /// words on a console that is narrow.
        /// </summary>
        private Line GameHud(int max, bool ansi)
        {
            int done = FinishedCount();
            int percent = _total > 0 ? (int)Math.Min(100L, 100L * done / _total) : 0;
            string[] runs =
            {
                "run " + ProgressText(done, CurrentPhaseClock(), false),
                N(done) + "/" + N(_total) + "  " + N(percent) + "%",
                N(done) + "/" + N(_total)
            };
            string times = Unicode ? "×" : "x";
            // The words of the left side and of the right side, from the most to the fewest.
            int[][] forms = { new[] { 0, 0 }, new[] { 1, 0 }, new[] { 1, 1 }, new[] { 1, 2 }, new[] { 2, 1 }, new[] { 2, 2 } };
            Line line = null;
            foreach (var form in forms)
            {
                var left = new LineBuilder(ansi).Add(" ").Add(form[0] < 2 ? "MAESTER RUN" : "RUN", GameOrange).Add("  ");
                // The hearts that are left, and after them the ones that are gone, each on its own.
                for (int h = 0; h < Runner.Hearts; h++)
                {
                    if (h > 0) left.Add(" ");
                    if (h < _game.Lives) left.Add(Unicode ? "♥" : "*", "1;31");
                    else left.Add(Unicode ? "♡" : ".", "2");
                }
                left.Add("  ");
                left.Add("SCORE ", "2").Add(GameNumber(_game.Score), "1").Add("  ");
                // A count of pick-ups in a row, not a factor: the sign is only for the form without the word.
                left.Add(form[0] < 2 ? "STREAK " : string.Empty, "2").Add((form[0] < 2 ? string.Empty : times) + N(_game.Streak), _game.Streak > 0 ? "1;32" : "2");
                if (_gameBest > 0 && form[0] == 0) left.Add("  ").Add("BEST " + GameNumber(_gameBest), "2");
                var right = new LineBuilder(ansi).Add(runs[form[1]], "1").Add("  ");
                right.Add(Ok + " " + N(_passed), "32").Add("  ").Add(Bad + " " + N(_failed), _failed > 0 ? "31" : "2").Add("  ").Add("! " + N(_error), _error > 0 ? "33" : "2");
                var l = left.Build();
                var r = right.Build();
                string gap = new string(' ', Math.Max(2, max - l.Plain.Length - r.Plain.Length));
                line = new Line { Text = l.Text + gap + r.Text, Plain = l.Plain + gap + r.Plain };
                if (line.Plain.Length <= max) break;
            }
            return Truncate(line, max, ansi);
        }

        /// <summary>How many tests failed in the run, in the words of the ticker and of the last card.</summary>
        private string GameStillFailed()
        {
            if (_failed == 0) return "nothing needs you for real";
            return N(_failed) + (_failed == 1 ? " still needs you for real" : " still need you for real");
        }

        /// <summary>
        /// The row above the keys: what happened last, with the test and the points, and at the right the
        /// reminder that the failed tests of the run are all still there.
        /// </summary>
        private Line GameTicker(int max, bool ansi)
        {
            string right = "in the game only: " + GameStillFailed();
            int kind = _game.LastKind;
            string head;
            string colour;
            if (kind == Runner.LastStomp) { head = Ok + " Stomped "; colour = "32"; }
            else if (kind == Runner.LastCoin) { head = (Unicode ? "● " : "o ") + "Collected "; colour = "33"; }
            else if (kind == Runner.LastHit) { head = Bad + " Hit by "; colour = "31"; }
            else if (kind == Runner.LastBite) { head = Bad + " Bitten by "; colour = "31"; }
            else if (kind == Runner.LastAhead) { head = "! Ahead, and it takes two jumps: "; colour = "1;35"; }
            else { head = string.Empty; colour = null; }
            string id = kind == 0 ? string.Empty : (_game.LastId ?? string.Empty);
            // A piece that stood for several results says how many.
            if (kind != 0 && _game.LastCount > 1) id = id.Length > 0 && kind != Runner.LastCoin ? id + " and " + N(_game.LastCount - 1) + " more" : N(_game.LastCount) + " passed tests";
            // Points are for tests that were collected or stomped. What the game put in the way itself has none.
            bool earned = (kind == Runner.LastCoin || kind == Runner.LastStomp) && !_game.LastFree;
            string points = earned ? " +" + N(_game.LastPoints) : string.Empty;
            if (1 + head.Length + id.Length + points.Length + 2 + right.Length > max) right = GameStillFailed();
            var left = new LineBuilder(ansi).Add(" ");
            if (kind == 0)
            {
                // Before anything happened: what the game is, in as many words as fit.
                string[] hints = { "The run is the course: passed tests are coins, failed tests are in your way. Jump on them.", "Passed tests are coins. Jump on the failed ones.", "Jump on the failed tests." };
                string hint = hints[hints.Length - 1];
                for (int i = hints.Length - 1; i >= 0; i--)
                {
                    if (1 + hints[i].Length + 2 + right.Length <= max) hint = hints[i];
                }
                left.Add(hint, "2");
            }
            else
            {
                left.Add(head, colour).Add(id, "1");
                int room = max - right.Length - 2 - left.Length - points.Length - 1;
                string title = _game.LastCount > 1 ? string.Empty : (_game.LastTitle ?? string.Empty);
                if (title.Length > room) title = room >= 4 ? title.Substring(0, room - 1) + (Unicode ? "…" : ".") : string.Empty;
                if (title.Length > 0) left.Add(" " + title, "2");
                left.Add(points, "1;33");
            }
            var l = Truncate(left.Build(), Math.Max(1, max - right.Length - 2), ansi);
            string gap = new string(' ', Math.Max(2, max - l.Plain.Length - right.Length));
            var r = new LineBuilder(ansi).Add(right, "2").Build();
            return Truncate(new Line { Text = l.Text + gap + r.Text, Plain = l.Plain + gap + r.Plain }, max, ansi);
        }

        /// <summary>
        /// The last row: the keys, on the colours of the status bar, across the whole width. As in the
        /// status bar of the dashboard, the keys are in two groups, one at each edge, and each key is in
        /// one colour of text, the one that reads on the middle of it: no key turns from white to dark
        /// part way along where the bar goes from red to amber.
        /// </summary>
        private Line GameKeys(int max, bool ansi)
        {
            string back = "Esc back to the dashboard";
            string sound = "M sound " + (GameSoundOn ? "on" : "off");
            string[] left;
            string[] right;
            if (_gameEnded)
            {
                left = new string[0];
                right = new[] { back };
            }
            else if (_game.Over)
            {
                left = new[] { "Enter play again" };
                right = new[] { sound, back };
            }
            else
            {
                left = new[] { "Space jump", "Space again in the air: double jump", "P pause" };
                right = new[] { sound, "? help", back };
                if (KeyRowLength(left, right) > max)
                {
                    left = new[] { "Space jump, twice in the air", "P pause" };
                    right = new[] { sound, "? help", "Esc dashboard" };
                }
            }
            // The row is the same from frame to frame, and with true colour every cell of it has its own colour.
            string key = string.Join("|", left) + "||" + string.Join("|", right) + "|" + N(max) + (ansi ? "a" : "p") + (TrueColor ? "t" : "c");
            if (_gameKeys != null && _gameKeysFor == key) return _gameKeys;

            // Where each key is: the left group from the left edge, the right group ending at the right one.
            var chars = new char[max];
            var owner = new int[max];
            for (int x = 0; x < max; x++) { chars[x] = ' '; owner[x] = -1; }
            var spans = new List<int[]>();
            int at = 1;
            foreach (var k in left)
            {
                spans.Add(new[] { at, k.Length });
                at += k.Length + 3;
            }
            // KeyRowLength counts the two edges and three columns after the last key: the group itself is five less.
            int end = max - 1 - (KeyRowLength(new string[0], right) - 5);
            at = Math.Max(end, at);
            foreach (var k in right)
            {
                spans.Add(new[] { at, k.Length });
                at += k.Length + 3;
            }
            var all = new List<string>(left);
            all.AddRange(right);
            for (int i = 0; i < all.Count; i++)
            {
                for (int j = 0; j < all[i].Length; j++)
                {
                    int x = spans[i][0] + j;
                    if (x < 0 || x >= max) continue;
                    chars[x] = all[i][j];
                    owner[x] = spans[i][0] + all[i].Length / 2;
                }
            }
            string plain = new string(chars);
            var line = new Line { Text = plain, Plain = plain };
            if (ansi)
            {
                var sb = new StringBuilder();
                string colour = null;
                for (int x = 0; x < plain.Length; x++)
                {
                    string want = KeyRowColour(x, plain.Length, owner[x] >= 0 ? owner[x] : x);
                    if (want != colour)
                    {
                        sb.Append(Esc).Append(want).Append('m');
                        colour = want;
                    }
                    sb.Append(plain[x]);
                }
                line.Text = sb.Append(Esc).Append("0m").ToString();
            }
            _gameKeys = line;
            _gameKeysFor = key;
            return line;
        }

        /// <summary>The columns of the keys with a space at each edge and three between two keys.</summary>
        private static int KeyRowLength(string[] left, string[] right)
        {
            int length = 2;
            foreach (var k in left) length += k.Length + 3;
            foreach (var k in right) length += k.Length + 3;
            return length;
        }

        /// <summary>
        /// The colour of a cell of the key row: the background of the bar at the cell, and the text in the
        /// colour that reads on the bar at <paramref name="textColumn"/>, the middle of the key the cell is in.
        /// </summary>
        private string KeyRowColour(int column, int columns, int textColumn)
        {
            if (!TrueColor) return BarColour(column, columns, true);
            string background = BarColour(column, columns, true);
            string text = BarColour(textColumn, columns, true);
            // Both are "1;38;2;r;g;b;48;2;r;g;b": the text of the one and the background of the other.
            int fg = text.IndexOf(";48;2;", StringComparison.Ordinal);
            int bg = background.IndexOf(";48;2;", StringComparison.Ordinal);
            if (fg < 0 || bg < 0) return background;
            return text.Substring(0, fg) + background.Substring(bg);
        }

        /// <summary>
        /// The counter of the run, done/total, in large digits in the sky behind the playfield, with a
        /// caption: in the rows at the top that nothing of the course is in, so that no bridge crosses it
        /// and no name covers it. Two cells wide and two rows high for each dot of a digit where there is
        /// room, smaller where there is less, and left out where there is none: the first row has the
        /// same numbers.
        /// </summary>
        private void DrawGameBackdrop(Canvas canvas, bool ansi)
        {
            string text = N(FinishedCount()) + "/" + N(_total);
            int room = _game.SkyFree;
            int dotWidth;
            int dotHeight;
            if (canvas.Width >= text.Length * 12 + 2 && room >= 13) { dotWidth = 2; dotHeight = 2; }
            else if (canvas.Width >= text.Length * 12 + 2 && room >= 6) { dotWidth = 2; dotHeight = 1; }
            else if (canvas.Width >= text.Length * 6 + 2 && room >= 6) { dotWidth = 1; dotHeight = 1; }
            else return;
            int advance = 6 * dotWidth;
            int left = (canvas.Width - (text.Length * advance - dotWidth)) / 2;
            // The caption is under the digits, after an empty row where there is one.
            int gap = room >= 5 * dotHeight + 3 ? 1 : 0;
            int top = Math.Max(0, (room - 5 * dotHeight - gap - 1) / 2);
            // Without colour the digits are dots, so that what is drawn over them stands out.
            char dot = Unicode ? (ansi ? '█' : '·') : '.';
            for (int i = 0; i < text.Length; i++)
            {
                string glyph = GameDigits[text[i] == '/' ? 10 : text[i] - '0'];
                for (int cell = 0; cell < glyph.Length; cell++)
                {
                    if (glyph[cell] == ' ') continue;
                    for (int dy = 0; dy < dotHeight; dy++)
                    {
                        for (int dx = 0; dx < dotWidth; dx++) canvas.Put(left + i * advance + cell % 5 * dotWidth + dx, top + cell / 5 * dotHeight + dy, dot, GsBackdrop);
                    }
                }
            }
            const string caption = "tests completed";
            canvas.Text((canvas.Width - caption.Length) / 2, top + 5 * dotHeight + gap, caption, GsCaption);
        }

        /// <summary>The line of a game in numbers: coins, stomps, the best streak and the hits.</summary>
        private string GameTally(MtConsoleGameResult game)
        {
            string dot = Unicode ? " · " : ", ";
            return N(game.Coins) + (game.Coins == 1 ? " coin" : " coins") + dot + N(game.Stomps) + (game.Stomps == 1 ? " stomp" : " stomps") + dot +
                "best streak " + N(game.BestStreak) + dot + N(game.Hits) + (game.Hits == 1 ? " hit" : " hits");
        }

        /// <summary>
        /// The card in the middle of the playfield when the game stands still: the run is complete, the
        /// help was asked for, the game is over, or it is paused. The card of a complete run has the best
        /// game of the run.
        /// </summary>
        private void DrawGameCard(Canvas canvas)
        {
            var lines = new List<string>();
            if (_gameEnded)
            {
                var best = GameBestOfRun();
                lines.Add("RUN COMPLETE");
                lines.Add(string.Empty);
                lines.Add("SCORE " + GameNumber(best.Score) + " of " + GameNumber(GameFullScore));
                lines.Add(GameTally(best));
                if (best.Boss) lines.Add(best.BossDown ? "DC01 decommissioned" : "DC01 still standing");
                if (best.Games > 1) lines.Add("the best of " + N(best.Games) + " games");
                lines.Add("in the game only: " + GameStillFailed());
                lines.Add(string.Empty);
                lines.Add("Esc  back to the dashboard");
            }
            else if (_gameHelp)
            {
                DrawGameHelp(canvas, false);
                return;
            }
            else if (_gameSplash)
            {
                // The first time in a run: the card of the help, with a key to start.
                DrawGameHelp(canvas, true);
                return;
            }
            else if (_game.Over)
            {
                // The runner goes down first.
                if (_game.OverFor < Runner.OverSeconds) return;
                lines.Add("GAME OVER");
                lines.Add(string.Empty);
                lines.Add("SCORE " + GameNumber(_game.Score) + " of " + GameNumber(GameFullScore));
                lines.Add(GameTally(GameNow()));
                lines.Add("in the game only: " + GameStillFailed());
                lines.Add(string.Empty);
                lines.Add("Enter  play again     Esc  dashboard");
            }
            else if (_game.Paused)
            {
                lines.Add("PAUSED");
                lines.Add(string.Empty);
                lines.Add("P  go on     Esc  dashboard");
            }
            else
            {
                return;
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
                string text = lines[i].Length > inner ? lines[i].Substring(0, inner) : lines[i];
                int pad = (inner - text.Length) / 2;
                canvas.Cover(left + 1, top + 1 + i, new string(' ', pad) + text + new string(' ', inner - pad - text.Length), i == 0 ? GsCardTitle : (i == 2 ? GsCardText : GsCardDim));
                canvas.Put(left, top + 1 + i, v, GsCard);
                canvas.Put(left + inner + 1, top + 1 + i, v, GsCard);
            }
            canvas.Cover(left, top + lines.Count + 1, (Unicode ? "╰" : "+") + Repeat(h, inner) + (Unicode ? "╯" : "+"), GsCard);
        }
    }
}
