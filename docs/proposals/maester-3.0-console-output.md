# Maester 3.0 console output: plan

Status: accepted and implemented in PR 2334, following the owner's rulings of 2026-10-10 (below). It extends design
section 5.4 (console levels) and rule 11 ("the engine owns progress and console output").

## Owner rulings (2026-10-10)

1. In Interactive mode at `-Verbosity None`, print **no** per-test lines, not even Failed and Error. Live result
   counts are the interactive feedback.
2. CI annotations: no ruling. Implemented as on by default in Stream mode, capped at 20, with `Output.CIAnnotations = $false`
   to turn them off.
3. Keep the logo. The interactive banner follows the GitHub Copilot CLI: a block wordmark with an outline, next to the
   official Maester flame, with the connection info under it.
4. Write the renderer in C#, in Maester.Engine.
5. While a run is in progress the console may take over the whole screen. It shows a dashboard: the overall phase,
   one lane per product, and the tests that are running. It has to work for parallel runs, and for phases Maester
   does not have yet (collecting data, as the Zero Trust Assessment does).
6. Tests are grouped by product. `Product` is a property of `[MaesterTest]`, set on every built-in test; nothing parses
   it out of another value.
7. The summary is a table of results by product, then the totals and the report link.

## Where we were

How a 3.0 run wrote to the console before this work:

| What | How | Problem |
| --- | --- | --- |
| Phase progress ("Reading Maester config…", "Discovering native tests…", reports) | `Write-MtProgress` → `Write-Progress`, 18 call sites in `Invoke-Maester` | The ConsoleHost redraws progress at most every 200 ms, and every host write hides the progress pane, so the bar flickers or never appears. The macOS first-record bug (PowerShell#5741) was closed as stale, never fixed. The `-Force` workaround slept 200 ms per call: 1.6 s per run before this PR, now once per session and only on a visible console. |
| Per-test progress | `Add-MtTestResultDetail` calls `Write-MtProgress -Status <test name>` | It runs only for tests that call it, so skipped tests and tests that throw don't move the bar. There's no count, percentage or elapsed time. In 3.0 the engine knows when every test starts and finishes, but it doesn't drive the progress. |
| Per-test results | `Write-MtNativeResultLine` (`Write-Host … -ForegroundColor`) at `-Verbosity Normal` and above | Only a colour carries the meaning, and the line format differs from Pester's. Nothing is printed at `None`, the default. |
| Pester-format tests | Pester's own output (`Output.Verbosity` mapped from `-Verbosity`) | It's a separate visual language in the same run. |
| Summary | `Write-Host` with emoji, plus the report path | Emoji have ambiguous width. Paths aren't clickable. There's no failure list. |
| Logo, connection summary, consent help | `Write-Host` | Fine. Out of scope apart from respecting the output mode. |

## Goals

1. **Show progress for the whole run in interactive terminals.** You can see how far through the run is, what is running and for how long, and the pass/fail counts so far, without flicker and without slowing the run down.
2. **Use the same contract everywhere.** Behaviour matches design 5.4: at least one record per finished test at `Normal`, nothing per test at `None`. Result lines are permanent scrollback, and the live status is never written to a log.
3. **Degrade cleanly.** Stream mode for CI and redirected output (no cursor movement), and plain mode for `TERM=dumb` and screen readers. `NO_COLOR` turns colour off in every mode.
4. **Add no new dependency.** No Spectre.Console: it adds five DLLs, can clash with assemblies that Graph, Az or EXO load, and needs encoding set before import. PowerShell 7.4+ and VT sequences are enough.
5. **Stay ready for parallel lanes.** When `MaxParallel > 1` arrives, results come from pool threads, so the renderer has to be thread-safe from the start.

## Design

### Output modes (chosen once, at the start of `Invoke-Maester`)

`Get-MtConsoleMode` decides the mode:

| Mode | When (`Auto`) | Live status | Colour | Symbols |
| --- | --- | --- | --- | --- |
| `Interactive` | ConsoleHost with virtual terminal support, stdout not redirected, not CI, not `-NonInteractive` | A full-screen dashboard, or a status line and a two-line region on a small console | ANSI | `✓ ✗ ! ? –` (single width) |
| `Stream` | CI (`CI`, `GITHUB_ACTIONS`, `TF_BUILD`), redirected output, another host (VS Code, Azure Automation, remoting), `-NonInteractive` | In CI, a heartbeat line every 10 s or 50 tests | ANSI where the host supports it, and on GitHub Actions | single width |
| `Plain` | `TERM=dumb`, or chosen | none | none | ASCII `[PASS] [FAIL] [ERROR] [SKIP] …` |

- **Choosing the mode:** `-OutputMode Auto|Interactive|Stream|Plain` comes first, then `MAESTER_OUTPUT_MODE`,
  then `Output.ConsoleMode` in maester-config.json.
- **Interactive needs a real console:** it falls back to Stream when there is no console it can draw on.
- **Colour:** `NO_COLOR` turns colour off in every mode.

`-Verbosity` still decides *what* is printed, and the mode decides *how*:

- At `None`, Interactive shows the dashboard and then the summary, with no per-test lines (ruling 1).
- At `None`, Stream and Plain print only the summary, plus the heartbeat in CI.
- At `Normal` and above, every mode prints one line per finished test: symbol and word, ID, title, duration, and for
  Failed and Error the first line of the reason. Interactive uses the compact layout so the lines can scroll.

### Interactive: the dashboard

At `-Verbosity None` on a console of at least 80 columns by 16 rows, the run takes over the screen. It uses the
terminal's alternate screen, as `less` and `vim` do, so nothing it draws ends up in the scrollback and it can
redraw freely.

The banner (the flame and the wordmark, 13 rows) is the opening screen: it is shown while the run prepares. Once
the tests start it makes room for them: the top of the main column is a band of five rows, with a four-row
wordmark at the left and the Pace graph to its right. The wordmark is in the four rows of the graph, so the
letters stand on the same line as the bars, and the version (and a newer version when there is one) is in the row
of the caption of the graph. There is no flame in the band. The phases and the overall progress are the two lines under it. A console of
fewer than 26 rows, or one too narrow for the logo and a graph, gets one line: the name in the colours of the
wordmark, the version and the phases; the Pace graph is then under the product lanes when there are rows for it.
The sketch below is the opening screen.

```
┌──                                                                                  ──┐
     ▟██████  ▟▙       ███╗   ███╗ █████╗ ███████╗███████╗████████╗███████╗██████╗
     (the flame)       ...
└──                                                                                  ──┘
 ● Graph  ● Exchange Online  ○ Teams

 ✓ Prepare 1.0 s  ─  ● Run tests 0:15  ─  ○ Results  ─  ○ Reports

 ━━━━━━━━━━━━━━━━━━━━────────────────────  269/431  62%  ETA 0:44   ✓ 212  ✗ 41  ! 3  ? 9  – 4

 Entra ID        ━━━━━━━━━━━━━━━━━━━━━━━━  182/182  ✓ 150  ✗ 28  ! 0  ? 4
 Exchange Online ━━━━━━━━━━━━━━━─────────    61/98  ✓ 48   ✗ 11  ! 2  ? 0   2 running
 Defender        ━━━━━───────────────────   26/127  ✓ 14   ✗ 2   ! 1  ? 5   1 running
 Teams           ────────────────────────      0/0                          24 skipped

 Running · 3 tests
 ⠸ MT.1041           Mailbox auditing is enabled for all users                        2.4 s
 ⠸ CISA.MS.EXO.4.1   DMARC records are published for every domain                     0.8 s
 ⠸ MT.1059           Defender for Identity health issues are resolved                 5.1 s
```

- **Phases.** The strip shows the phases of the run in order: done (with its time), current, and to come. Today they are
  Prepare, Run tests, Results and Reports. The renderer takes the list from the caller (`SetPhases`, `StartPhase`), so a
  data collection phase can be added without changing the renderer. Outside the test phase, the line under the strip
  shows what the phase is doing ("Creating html report…").
- **Lanes.** One per product, from the `Product` of each test, in the order of the schema's product list. A product
  whose tests are all skipped gets a lane with the number skipped, so it is clear why nothing runs for it. When there
  are more lanes than rows, the lanes with work left stay and the rest are counted in "… and n more".
- **Running tests.** One line per running test with its elapsed time. With one worker it is one line; with parallel
  lanes it is one per worker. Results are matched to their test by ID, so they can finish in any order.
- **Size.** The banner is shown when the console is wide and tall enough for it next to everything else. Otherwise the
  header is one line. The width and height are read on every redraw, so resizing works.
- **Redraw.** Every 100 ms and on every event: home the cursor, write each line followed by erase-to-end-of-line, then
  erase below, all inside a synchronized-output bracket (`` `e[?2026h `` … `` `e[?2026l ``).
- **What the tests write.** There is no scrollback while the dashboard is up. Warnings and `Write-Host` output from
  tests stay on the engine's result, and anything Maester itself wants to print is queued. Both are written, in order,
  as soon as the screen is restored.
- **When the run ends.** The screen is restored, and the scrollback gets the banner (printed before the dashboard
  opened), the connection list, the queued output and the summary.
- **Taskbar progress.** OSC `9;4` in Windows Terminal, ConEmu, Ghostty and iTerm2 3.6.6+, detected from the environment.
  It is never sent to older iTerm2, which shows OSC 9 as a notification.
- **Cleanup.** `Invoke-Maester` has a `clean {}` block (PowerShell 7.3+) that restores the screen and the cursor on
  every path out: normal return, early return, error and Ctrl+C.

**Interactive runs never call `Write-Progress`.** The host's progress pane finds its place by asking the terminal for the
cursor position (`ESC[6n`). A terminal that doesn't answer in time gets the pane, and anything drawn after it, at the top
of the screen. This happened in the Claude desktop app's embedded terminal. The renderer never reads the cursor position.

### Dashboard panels

On a console of about 140 columns or more the dashboard has a second column on the right. The dashboard fills the
window: the main content takes 98 columns, the right column grows to 58 (a 160-column console), and beyond that the
extra width is shared, two parts to the main content (longer bars, more squares per row) and one to the right column
(up to 90 columns). The rows under the running tests list the tests that ran before them, newest first, each with the mark of its
result and its duration. The last row of the window is a status bar across the whole width, on the gradient of the wordmark (Maester red to
amber; one orange without true colour), with a group of links at each edge and, between them, which click opens a link ("⌘-click to open" on macOS, "Ctrl-click to open" elsewhere): maester.dev,
Docs (maester.dev/docs), Contributors (maester.dev/contributors), Our Manifesto (maester.cloud/manifesto), Star on GitHub (the repository),
Discord (discord.maester.dev), Issues and Sponsor (the Sponsor dialog of the repository, fed by
`.github/FUNDING.yml`), each a hyperlink. With the bar on screen the tagline under the logo
has the version only. Rows that are free go to the results chart (up to 16 rows, one square per test while they fit).

Every panel of the right column is shown whenever the column has the rows for it. The Slowest panel is the one that
gives: it starts at one test, and takes the rows that are left over for more (twenty at most). In a column that is still too short the panels that can do with less take less (the Tips panel the
height of the tip it shows instead of that of its longest tip, the Failed panel only the severities that have
failures, the Blog panel one line); only then is a panel that does not fit left out. With the default panels that
takes a window of about 44 rows. `Output.DashboardPanels` in maester-config.json chooses the panels and their order; the
default is all of them, and an empty list turns them off.

| Panel | Shows | Where it comes from | Cost |
| --- | --- | --- | --- |
| `Tenant` | Tenant name with the primary domain on the right of the same line, and the account and auth type under them. Without a Graph connection (or with `-SkipGraphConnect`) it says so. | The tenant context of the run: the name, the domain and the tenant type come from the one `organization` request every run makes; the account from the local Graph context. Nothing is requested for the panel. | none |
| `Totals` | The results so far as one bar across the panel, split by result (passed, failed, errors, investigate, skipped) in the share each has of the tests that finished, exact to an eighth of a cell, and under it the count and the share of each result that has tests. A part of the bar is never thinner than a twenty-fifth of it, so that one failure among hundreds of passed tests shows. A ring chart was tried first; at five rows of a terminal it cannot be made smooth. | Counters updated as results arrive | none |
| `Connections` | The services of the run in a grid: a green dot when connected, a hollow one when not, and how many are connected in the border. A name that is too long is cut at its end. With this panel on screen there is no connection line under the banner. | The tenant context of the run | none |
| `Failed` | Failed tests by severity, as bars | Each result as it arrives | none |
| `Drift` | How long ago the last run was ("4 days ago"), its date (a hyperlink that opens the HTML report of that run, when it is next to the results file) and its passed, failed and investigate counts, then the newly failing, fixed and new tests against it. Left out when there is no earlier run. | The newest earlier results JSON in the output folder, read on a background thread. A file from another tenant is ignored. | 30 to 75 ms once |
| `Slowest` | The tests that took the longest: always one, and more (twenty at most) in the rows of the column that no other panel needs. A test that was skipped did not run and is not listed. | The time each test took, kept as it finishes | none |
| `Pace` | At the top of the main column, to the right of the small logo and in its rows: a graph of how long each test took (four rows), and a line under it with the tests per second and the longest test. On a console that is too small for that band the graph is between the product lanes and the result blocks, two to five rows tall as the console has room. The graph has one bar for each test that ran, in the order they ran: it fills from the left with every test that finishes (a quick one is a low green bar), and once it is full it shows the latest tests, the newest at the right edge, and moves left as tests finish. Its height is on a logarithmic scale against the longest test of the whole run, exact to an eighth of a row, and each row has its colour, green at the bottom to red at the top. It is left out on a console that is too short for it. | The time each test took, kept as it finishes | none |
| `Contributor` | Featured contributor: one of the people who built Maester, a different one every minute, starting with a different one each run. The name and the GitHub handle (both a hyperlink to the person's page on maester.dev/contributors), how many tests they wrote and how many they improved (a count of nothing is left out), and the year of their first contribution. | `assets/ConsoleContributors.json`, which ships with the module. `build/Update-ConsoleContributors.ps1` writes it from the contributor data of the website, and the module build runs it. People who are pinned last on the contributors page are left out. | none |
| `Blog` | The newest post on maester.dev: its title, a hyperlink (OSC 8) to the post, over two lines at most, and its date in the border. Emoji are left out of the title, because terminals do not agree on their width. | `maester.dev/blog/rss.xml`, on a background thread, cached for a day in the user's local application data folder | one web request |
| `Version` | Not a panel: when a newer stable Maester is on the PowerShell Gallery, the tagline under the logo says so ("v3.0.0 · ↑ v3.1.0 available · maester.dev"), in bold amber, as a hyperlink to that version in the gallery. | The gallery, on a background thread | one web request |
| `Tips` | One tip at a time, changing every twelve seconds, with a hyperlink to the page on maester.dev that says more | `assets/ConsoleTips.txt` in the module | none |
| `Results` | One square per test under the product lanes, edge to edge, filled in the order tests finish and coloured by result. A test that is running shows a spinner like the one of the list of running tests, as tall as a square. Blocks of two or three cells were tried: a block bigger than a cell cannot have thin gaps of the same size on both sides with characters every terminal font has, so the one-cell square stays. With more tests than squares, each square stands for several and takes the colour of its worst result. | Each result as it arrives | none |

- Each panel in the right column is a rounded box with its title in the top border, and where there is one a badge
  on the right of that border (the failed count, the date of the last run, tests per second). The border takes the
  colour of the panel's state: red when tests have failed, amber when tests are newly failing or an update is
  available, green when the only drift is fixes, grey otherwise. This is the btop and lazygit convention, chosen by the
  owner from ten mocked styles. Without Unicode the boxes are drawn with `+`, `-` and `|`.
- A box costs two columns and two rows, so one panel fewer fits than without borders.
- A panel with nothing to show is left out (no drift without an earlier file, no blog offline), and a panel that does
  not fit in the rows that are left is skipped.
- The connection line stays under the banner at every width (owner ruling: the services belong in the main
  content, not in a panel). On a narrower console the right column is gone.
- `Blog` and `Version` are the only ones that use the network. They are started only when the dashboard is wide
  enough to show them, never with `-SkipVersionCheck`, with a five-second timeout, and a failure shows nothing.
- The text panels are filled by the caller (`SetPanelText`); the live ones are worked out in the renderer from
  `ItemFinished(id, result, severity)`. Building a frame with every panel takes well under a millisecond.

### Interactive: the compact layout

Used when the console is smaller than 80 by 16, and at `-Verbosity Normal` and above, where per-test lines have to
scroll past.

- Before and after the tests, one dim status line shows what the run is doing ("› Reading the tenant context…"). It is
  drawn when the text changes, and left with the cursor at its start, so a line the host writes replaces it.
- While tests run, two lines at the bottom are redrawn in place: the counts, a bar, done/total and ETA, then the running
  test. Host output (result lines, replayed warnings) is written between `Pause()` and `Resume()`.

```
⠸ ✓ 32  ✗ 6  ! 0  ? 0  – 0  ━━━━━━━━━━━━━━━━━━━───────────  38/60  63%  0:20  ETA 0:11
  CONTOSO.44  Mailbox auditing is enabled (44) (0:01)
```

### Where it lives

`MtConsoleRenderer` in Maester.Engine (C#) draws both layouts:

- Content: `SetHeader`, `SetInfo`, `SetPhases`, `StartPhase`, `ShowStatus`.
- Lifecycle: `Open` (takes the screen when it can), `Start` (with the lanes), `ItemStarting`, `ItemFinished`, `Pause`,
  `Resume`, `Stop` (ends the test phase), `Close` (gives the screen back).
- One lock for every call, because a timer thread redraws and parallel lanes will report from several threads.
- It writes to a `TextWriter` (`Console.Out`), and takes a fixed width and height, so its tests use a `StringWriter`.

`Invoke-MtEngineRun -Renderer`:

- Reports each item start to the renderer, with the item's `Title` and `Group` (its product).
- In the compact layout, pauses the renderer around the records it replays after a test. In the dashboard it leaves
  them on the result for the caller to replay later.
- Sets `$ProgressPreference = 'SilentlyContinue'` inside tests, because a module's own `Write-Progress` would draw over it.

The PowerShell side owns the decisions:

- Mode detection (`Get-MtConsoleMode`), the banner (`Get-MtBanner`), the connection info (`Get-MtConnectionInfo`).
- The phases (`Set-MtConsolePhase`) and what each is doing (`Write-MtProgress` goes to `ShowStatus` during an
  interactive run).
- Turning each finished test into its Maester result. `Invoke-MtNativePlan` builds rows in `OnItemFinished`, so the live
  counts and the report agree.
- Everything that stays in the scrollback: `Write-MtConsoleLine` pauses the compact layout around a `Write-Host`, or
  queues the line while the dashboard is up. `Stop-MtConsoleOutput` closes the renderer and writes the queue.

Pester-format tests run after the native tests. Pester writes its own output, so the screen is given back before
`Invoke-MtPesterProvider` runs.

### Stream mode in CI

- Native tests go inside a log group: `::group::` / `::endgroup::` (GitHub Actions), `##[group]` / `##[endgroup]` (Azure Pipelines).
- A heartbeat (`[Maester] 300/746 tests (40%), 12 failed or errored, 2:10`) every 50 tests or 10 seconds, plus
  `##vso[task.setprogress]` on Azure Pipelines.
- After the run, the first 20 Failed and Error rows become annotations, followed by one line with the number left out.
  Failed rows are warnings, because they are findings in the tenant. Error rows are errors, because the test could not run.
  This happens even with `-NonInteractive`, which is how CI usually runs Maester.

### Summary

A table with one row per product: Passed, Failed, Errors, Investigate, Skipped, and the highest severity among the
product's failed tests. Tests that were not run are left out, and tests without a `Product` are under Other. Then one
line of totals (symbol, number and word, so it never relies on colour alone) with the number of tests and the duration,
and the report path, which is an OSC 8 hyperlink in Interactive mode on terminals that support it.

```
 Product          Passed  Failed  Errors  Investigate  Skipped   Worst failure
 Entra ID            150      28       0            4        0   Critical
 Exchange Online      79      15       2            2        0   High
 ─────────────────────────────────────────────────────────────────────────────
 ✓ 229 passed  ✗ 43 failed  ! 2 errors  ? 6 investigate  – 0 skipped  – 0 not run  (280 tests, 1:58)
 Report ./test-results/TestResults-2026-10-10-121500.html
```

### Connection info

After the tenant context is read, the run lists the services it uses: connected ones with a filled dot (Graph with the
tenant name and account), and services that are not connected with the number of tests skipped for them. Opt-in
services (Active Directory) are only listed when connected. It reads the tenant context the run already has, so it
makes no calls. The dashboard shows it as one line under the banner.

### Banner

What other CLIs do:

- **GitHub Copilot CLI** shows a block wordmark with an outline next to a pixel-art mascot, inside corner brackets,
  with the version and connection lines under it. It is animated on first run (`banner: always|once|never`) and
  skipped with `--screen-reader`.
- **Gemini CLI** picks the widest of three ASCII logos that fits and colours it with a theme gradient.
- **opencode** prints a 256-colour half-block wordmark, and plain text when not on a TTY.
- **Claude Code** shows a compact box with the version and folder.

Maester's banner (`Get-MtBanner`, printed by `Show-MtLogo` and used as the dashboard header):

- **Wordmark.** The "ANSI Shadow" MAESTER wordmark with a gradient from left to right, Maester red `#E5243B`
  through orange `#FF6A3D` to amber `#FFB547`. The box-drawing shadow characters are a darker shade of the same
  colour (owner ruling: this over the light outline of the Copilot banner).
- **Flame.** The official logo (`assets/logo/maester.png`), sampled into quadrant characters (`▘▝▖▗▚▞▛▜▙▟`): two by two
  pixels per character cell, which every terminal font has. It is static art in the source; nothing reads the image at
  run time. It has the logo's own gradient, orange `#F7941D` at the top to red `#D6282F` at the bottom. With true colour or 256 colours a
  full cell is an upper half block on a background of the next shade, which gives two steps of the gradient per
  row.
- **Windows.** A Windows console starts with the output code page of the system, in which the symbols, the
  borders and the flame cannot be written. In Windows Terminal and the terminal of VS Code an interactive run
  switches the console to UTF-8 and puts the earlier encoding back when it ends; other Windows consoles get
  plain characters.
- **Colour.** Truecolor when `COLORTERM`, `WT_SESSION` or `TERM_PROGRAM` says the terminal supports it, then the
  256-colour cube, then yellow and red.
- **Sizes.** 88 columns by 13 rows at 90 columns or more. Below that, a small flame next to a two-line wordmark
  (37 columns). Below 40 columns, in Stream or Plain mode, or without UTF-8, one plain line.
- **No animation.** `-NoLogo` and `-NonInteractive` still turn the banner off.

### Accessibility

Plain mode has no animation, no cursor movement and no meaning carried by colour. Every result is shown as a word, and
the summary is linear. `-OutputMode Plain` and `MAESTER_OUTPUT_MODE=Plain` are documented for screen-reader users.

## Not done (follow-ups)

- **Parallel execution itself.** The dashboard and the renderer's API are ready for it; the engine still runs tests one at a time.
- **A data collection phase.** The phase list is the caller's, so adding one is a `SetPhases` change plus reporting its
  work as running items.
- **Screen-reader detection.** PSReadLine does this on Windows (`SPI_GETSCREENREADER`); Maester doesn't yet.
