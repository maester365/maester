## Previous-ID table (`Maester.LegacyIds.json`)

`powershell/assets/Maester.LegacyIds.json` maps every built-in test ID that ever
appeared in an `It` name under `tests/` (excluding `tests/Custom`) to its current
ID, or to `retired`. Maester 3.0 uses it to recognise stale copies of 2.x built-in
wrappers. `FamilyPrefixes` lists the parent IDs of family wrappers whose IDs are
built at runtime (`MT.1024.`, `MT.1033.`, ...); those are matched by prefix.

Regenerate it after a change to `tests/` that renames or removes a check:

```powershell
./build/golden/Export-MtLegacyIdTable.ps1 -Verbose
```

- The script walks `git log` over `tests/**/*.Tests.ps1` (about 90 seconds) and
  needs full history (no shallow clone).
- Mapping rules, in order: `manual` (the `$ManualOverrides` table at the top of the
  script), `prefix` (known prefix renames such as `MS.` to `CISA.MS.`), `title`
  (same normalised title), `function` (same single `Test-*` function called),
  otherwise `retired`.
- `-Verbose` prints counts by rule and a `REVIEW` line for each ambiguous, conflicting
  or title-only match. Resolve ambiguous ones by adding them to `$ManualOverrides`.
- `GeneratedFrom` is the last commit that touched the scanned test files, so the
  output only changes when `tests/` changes.
- `powershell/tests/general/LegacyIds.Tests.ps1` checks that no legacy ID is a current ID
  and that every target ID still exists. If it fails after you rename or remove a
  check, regenerate the table.
