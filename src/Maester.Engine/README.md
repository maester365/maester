# Maester.Engine

The compiled part of the Maester module: the `[MaesterTest]` and `[MaesterParameter]`
attribute types and the scheduling core (`Invoke-MtEngineRun`). Everything else in
Maester is PowerShell. See section 5.5 of
[the Maester 3.0 design](../../docs/proposals/maester-3.0-design.md).

The built DLL is committed at `powershell/lib/Maester.Engine.dll` and loaded through
`NestedModules` in the module manifest. Contributors who do not change the engine need
no .NET SDK.

## Changing the engine

1. Install the .NET SDK version pinned in [`src/global.json`](../global.json).
2. Edit the source here.
3. Rebuild and copy the DLL into the module:

   ```powershell
   ./build/Build-MaesterEngine.ps1
   ```

4. Run the engine tests:

   ```powershell
   Invoke-Pester ./powershell/tests/functions/engine
   ```

5. Commit the source change and the rebuilt DLL together. The `build-engine` workflow
   rebuilds the DLL and fails if the bytes differ from the committed file, then loads it
   and runs the engine tests on Windows, Linux and macOS.

After rebuilding, start a new PowerShell session: a loaded DLL cannot be replaced in a
running process.

## What the scheduler guarantees

- One `MtRunResult` per work item, in order for the main lane.
- With `-MaxParallel 1` (the default) every item runs nested on the caller's runspace,
  so connections made by `Connect-Maester` work as they do in a normal function call.
- The engine owns the `try`: a terminating or statement-terminating error ends the test
  and is reported as `Error`. A record with error ID `MaesterTestSkipped` is reported
  as `Skipped`.
- `exit`, or `break`/`continue` outside a loop, ends only the test (`Aborted`).
- A per-item deadline stops the test with `BeginStop` and reports `Timeout`. Ctrl+C
  stops the in-flight test and reports the remaining items as `NotRun`.
- Warning, verbose, debug and information records are captured on the result and
  replayed on the cmdlet's own streams.
- The scheduler reports how a test ended (`Status`, `ReturnKind`). Turning that into a
  Maester result (`Passed`, `Failed`, `Investigate`, reason codes) is done in PowerShell.
