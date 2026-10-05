# Error-path fixtures for the native test engine

Frozen inputs for the Maester 3.0 engine's unit tests. Each `Test.FIXTURE.<n>.ps1` is a
native-format test (design sections 3.1 and 3.2): one function carrying
`[MaesterTest(...)]` and nothing else at the top level, with a `Test.FIXTURE.<n>.md`
beside it. Each fixture exercises one row of the test contract in design section 5.2,
or one error path that a parity run against a healthy tenant would never reach.

`expected.json` maps every fixture ID to the expected `Result` and `ReasonCode`.
`designSpecified: false` marks a case that the 5.2 table does not cover (`break` and
`exit`); its expectation is a proposal to confirm when the engine is built.

## Rules for these files

- **Data only until the engine exists.** The `MaesterTest` attribute type ships in
  `Maester.Engine.dll` (design section 5.5). Do not dot-source or import these files
  in a test that runs without the engine: PowerShell would fail to resolve the
  attribute type.
- **Do not edit to make a test pass.** If the engine and a fixture disagree, fix the
  engine or change the design and `expected.json` together.
- **Not unit tests.** `powershell/tests/pester.ps1` only runs `*.Tests.ps1` from
  `general/` and `functions/`, so nothing under `fixtures/` runs as part of the
  module's unit test suite.
- `FIXTURE.0016` calls `exit`. Run it only through the engine, never directly in a
  shell you want to keep.
- `FIXTURE.0017` sleeps for 30 seconds. Use it only in timeout tests, with
  `Execution.TestTimeoutSeconds` set below 30.

## Fixtures

| ID | The test does | Result | Reason code |
| --- | --- | --- | --- |
| FIXTURE.0001 | returns `$true` | Passed | |
| FIXTURE.0002 | returns `$false` | Failed | |
| FIXTURE.0003 | returns `$null`, no skip, no `-Investigate` | Skipped | NoResult |
| FIXTURE.0004 | returns a string | Error | InvalidReturn |
| FIXTURE.0005 | returns two booleans | Error | InvalidReturn |
| FIXTURE.0006 | leaks `ArrayList.Add` output, then returns `$true` | Error | InvalidReturn |
| FIXTURE.0007 | throws | Error | TestError |
| FIXTURE.0008 | calls a method on `$null`, then returns `$true` | Error (never Passed) | TestError |
| FIXTURE.0009 | `Write-Error` (non-terminating), then returns `$true` | Passed, with Diagnostics | |
| FIXTURE.0010 | `-SkippedBecause NotApplicable`, no `return`, then the ORCA `return = $null` typo | Skipped | NotApplicable |
| FIXTURE.0011 | `-SkippedBecause Error` | Error | TestError |
| FIXTURE.0012 | `-Investigate`, then returns `$false` | Investigate | |
| FIXTURE.0013 | `-Investigate`, then returns `$null` | Investigate | |
| FIXTURE.0014 | skip raised inside its own `try`/`catch` | Skipped (TestSkipped = NotConnectedExchange) | TestSkipped |
| FIXTURE.0015 | `break` at the top level of the function | Error (proposed) | TestError |
| FIXTURE.0016 | `exit` | Error (proposed) | TestError |
| FIXTURE.0017 | sleeps 30 seconds, then returns `$true` | Error when the timeout is below 30 s, else Passed | Timeout |
| FIXTURE.0018 | writes warning, verbose, debug, information and host records | Passed; records re-emitted, warning in Diagnostics | |
| FIXTURE.0019 | `-Investigate`, then throws | Investigate | |

`FIXTURE.0006` and `FIXTURE.0008` were checked with a plain call outside any engine:
`0006` emits `0, True` and `0008` returns `True`. That is the 2.x behaviour the engine
must correct.
