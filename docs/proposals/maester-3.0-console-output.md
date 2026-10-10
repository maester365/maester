# Maester 3.0 console output: plan

Status: accepted and implemented in PR 2334, following the owner's rulings of 2026-10-10 (below). It extends design
section 5.4 (console levels) and rule 11 ("the engine owns progress and console output").

## Owner rulings (2026-10-10)

1. In Interactive mode at `-Verbosity None`, print **no** per-test lines, not even Failed and Error. The live result
   counts in the status region are the interactive feedback.
2. CI annotations: no ruling. Implemented as on by default in Stream mode, capped at 20, with `Output.CIAnnotations = $false`
   to turn them off.
3. Keep the logo, and refresh it for 3.0 with colour in interactive runs (see "Logo").
4. Write the renderer in C#, in Maester.Engine.

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
| `Interactive` | ConsoleHost with virtual terminal support, stdout not redirected, not CI, not `-NonInteractive` | Status line, then a live region during the tests | ANSI | `✓ ✗ ! ? –` (single width) |
| `Stream` | CI (`CI`, `GITHUB_ACTIONS`, `TF_BUILD`), redirected output, another host (VS Code, Azure Automation, remoting), `-NonInteractive` | In CI, a heartbeat line every 10 s or 50 tests | ANSI where the host supports it, and on GitHub Actions | single width |
| `Plain` | `TERM=dumb`, or chosen | none | none | ASCII `[PASS] [FAIL] [ERROR] [SKIP] …` |

- **Choosing the mode:** `-OutputMode Auto|Interactive|Stream|Plain` comes first, then `MAESTER_OUTPUT_MODE`,
  then `Output.ConsoleMode` in maester-config.json.
- **Interactive needs a real console:** it falls back to Stream when there is no console it can draw on.
- **Colour:** `NO_COLOR` turns colour off in every mode.

`-Verbosity` still decides *what* is printed, and the mode decides *how*:

- At `None`, Interactive shows the status line, the live counts and the summary, with no per-test lines (ruling 1).
- At `None`, Stream and Plain print only the summary, plus the heartbeat in CI.
- At `Normal` and above, every mode prints one line per finished test: symbol and word, ID, title, duration, and for
  Failed and Error the first line of the reason.

### Interactive: status line and live region

**Before and after the tests**, one dim status line shows the current phase ("› Reading the tenant context…").

- It is drawn when the phase changes, with no timer.
- It is left with the cursor at the start of the line, so a line the host writes without pausing replaces it instead of following it.

**Interactive runs never call `Write-Progress`.**

- The host's progress pane finds its place by asking the terminal for the cursor position (`ESC[6n`).
- A terminal that doesn't answer in time gets the pane, and anything drawn after it, at the top of the screen. This
  happened in the Claude desktop app's embedded terminal.

**While the tests run**, there are two lines at the bottom, redrawn in place:

```
⠸ ✓ 32  ✗ 6  ! 0  ? 0  – 0  ━━━━━━━━━━━━━━━━━━━───────────  38/60  63%  0:20  ETA 0:11
  CONTOSO.44  Mailbox auditing is enabled (44) (0:01)
```

- **Redraw:** move to the start of the region and erase it (`` `r`e[2K ``, `` `e[1A ``), then write the new frame as one write inside a
  synchronized-output bracket (`` `e[?2026h `` … `` `e[?2026l ``).
- **Timer:** redraws every 100 ms, so the spinner and the elapsed time of a long test keep moving.
- **Width:** the width is read on every redraw, and lines are cut to width − 1, so the region never wraps.
- **Resizing:** the erase works out how many rows the last frame now takes, so a console that got narrower doesn't leave rows behind.
- **Taskbar progress:** OSC `9;4` in Windows Terminal, ConEmu, Ghostty and iTerm2 3.6.6+, detected from the environment.
  It is never sent to older iTerm2, which shows OSC 9 as a notification.
- **Cleanup:** `Invoke-Maester` has a `clean {}` block (PowerShell 7.3+) that erases the region or status line and shows the cursor
  again. It runs on every path out: normal return, early return, error and Ctrl+C.

### Where it lives

`MtConsoleRenderer` in Maester.Engine (C#) draws only the status line and the region:

- `Start`, `ItemStarting`, `ItemFinished`, `ShowStatus`, `Pause`, `Resume`, `Stop`.
- One lock, and nothing is drawn while paused.
- It writes to a `TextWriter` (`Console.Out`), so its tests use a `StringWriter`.

`Invoke-MtEngineRun -Renderer`:

- Reports each item start to the renderer.
- Pauses the renderer around the records it replays after a test (warnings, `Write-Host` output).
- Sets `$ProgressPreference = 'SilentlyContinue'` inside tests, because a module's own `Write-Progress` would draw over the region.

Everything that stays in the scrollback goes through `Write-Host` between `Pause()` and `Resume()` (`Write-MtConsoleLine`).
Result lines, the summary and warnings therefore still reach the information stream and transcripts.

The PowerShell side owns the decisions:

- Mode detection, and the phase names (`Write-MtProgress` sends them to `ShowStatus` during an interactive run).
- Turning each finished test into its Maester result. `Invoke-MtNativePlan` now builds rows in `OnItemFinished`, so the live counts and
  the report agree.
- Formatting the result lines and the summary.

Pester-format tests run after the native tests, once the region has stopped, so Pester's own output is unchanged.

### Stream mode in CI

- Native tests go inside a log group: `::group::` / `::endgroup::` (GitHub Actions), `##[group]` / `##[endgroup]` (Azure Pipelines).
- A heartbeat (`[Maester] 300/746 tests (40%), 12 failed or errored, 2:10`) every 50 tests or 10 seconds, plus
  `##vso[task.setprogress]` on Azure Pipelines.
- After the run, the first 20 Failed and Error rows become annotations, followed by one line with the number left out.
  Failed rows are warnings, because they are findings in the tenant. Error rows are errors, because the test could not run.
  This happens even with `-NonInteractive`, which is how CI usually runs Maester.

### Summary

One line of counts (symbol, number and word, so it never relies on colour alone), the number of tests and the duration,
then the report path, which is an OSC 8 hyperlink in Interactive mode on terminals that support it. The summary replaces the
2.x line with emoji.

### Logo

What other CLIs do:

- **GitHub Copilot CLI** animates a 4-bit colour banner on first run (`banner: always|once|never`) and skips it with `--screen-reader`.
- **Gemini CLI** picks the widest of three ASCII logos that fits and colours it with a theme gradient. `ui.hideBanner` turns it off.
- **opencode** prints a 256-colour half-block wordmark, and plain text when not on a TTY.
- **Claude Code** shows a compact box with the version and folder.

Maester takes the static parts (`Show-MtLogo`):

- **Wordmark by width:** the "ANSI Shadow" wordmark (64 columns) at 72 columns or more, and a two-line half-block wordmark (31 columns)
  down to 36. Below that, or in Stream or Plain mode, or without UTF-8, it prints one plain line.
- **Gradient:** a fire gradient by column, from Maester red `#E5243B` through orange `#FF6A3D` to amber `#FFB547` (the red of maester.dev,
  and the 🔥 Maester uses everywhere). The box-drawing shadow characters are at 55% brightness so the letters stand out.
- **Colour depth:** truecolor when `COLORTERM`, `WT_SESSION` or `TERM_PROGRAM` says the terminal supports it, then the 256-colour cube,
  then red and yellow.
- **Info line:** one dim line, `v3.0.0 · PowerShell 7.6.2 · maester.dev`.
- **No animation.** `-NoLogo` and `-NonInteractive` still turn the logo off.

### Accessibility

Plain mode has no animation, no cursor movement and no meaning carried by colour. Every result is shown as a word, and
the summary is linear. `-OutputMode Plain` and `MAESTER_OUTPUT_MODE=Plain` are documented for screen-reader users.

## Not done (follow-ups)

- **Screen-reader detection.** PSReadLine does this on Windows (`SPI_GETSCREENREADER`); Maester doesn't yet.
- **Slowest tests and the first failures in the summary.** Left out for now, because ruling 1 keeps interactive output short.
- **Cold-start cost when other modules are installed.** When ExchangeOnlineManagement, MicrosoftTeams, PnP.PowerShell or Az are installed
  but not connected, the tenant-context probe auto-loads them. The first run on a machine then waits while PowerShell builds its
  module analysis cache: about 40 s on the author's machine before the first test. Checking `Get-Module <name>` before probing a
  service would avoid it.
