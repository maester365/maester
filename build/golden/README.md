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

## 2.x tag table (`Maester.LegacyTags.json`)

`powershell/assets/Maester.LegacyTags.json` maps each Maester 2.x tag to the IDs of the
built-in tests that carried it, and to the typed selector that replaces it where there
is an obvious one. Built-in tests no longer carry taxonomy tags in 3.0, so the engine
uses this table to keep `-Tag CA`, `-ExcludeTag MS.AAD.3.5` and every other 2.x tag
selecting the tests it selected. The tags are used for selection only and are never
written to a result row.

The table is derived from two frozen files, so it does not change when `tests/` changes:

- `powershell/tests/fixtures/golden/tags-and-blocks.json`, the 2.x snapshot;
- `powershell/tests/fixtures/golden/tags-3.0-preview.json`, the tags the 3.0 previews added.

```powershell
./build/golden/Export-MtLegacyTagTable.ps1
```

- A tag that is the ID of the one test that carried it is left out: the engine always
  treats a built-in test's own ID as a selection tag.
- A 2.x ID that 3.0 renamed is written as its 3.0 ID (`$RenamedIds` in the script).
- `$Replacements` in the script lists the typed selector for the suite, product and
  topic tags that have one; `Severity:<value>` tags get `-Severity <value>`.
- Tests added after 3.0 are not in the table. Do not add them, and do not edit the file
  by hand: `powershell/tests/functions/golden/Golden.Tests.ps1` checks that it is what
  the script produces, and that every 2.x tag still selects the tests it selected.
