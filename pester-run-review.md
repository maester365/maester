# Pester Run Review — `./powershell/tests/pester.ps1`

Branch: `feat-add-entra-external-id-tests`
Result: 9 / 7062 tests failed

## Summary

The failures fall into three categories: missing local tooling, pre-existing issues on `main`, and items that may be caused by local changes and need action before committing.

## 1. Pre-existing / environment-only (not related to this branch)

### `Set-MtGitHubActionsSecret.Tests.ps1` (3 failures)
- `gh` CLI not installed on this machine (`CommandNotFoundException: Could not find Command gh`).
- Expected locally; not a real failure. Install the GitHub CLI if you want these to pass.

### `PSScriptAnalyzer.Tests.ps1`
- `Get-ScriptAnalyzerRule` not recognized — the `PSScriptAnalyzer` module isn't installed.
- Same root cause as the `PSModuleDevelopment` warning seen at startup — local module set is incomplete.
- Fix: `Install-Module PSScriptAnalyzer, PSModuleDevelopment -Scope CurrentUser`

## 2. Likely pre-existing on `main`

### `LanguageNeutralMicrosoftUrls.Tests.ps1`
- Flags `https://learn.microsoft.com/en-us` links in:
  - `tests/maester/entra/Test.MT.1279.md:27`
  - `tests/maester/entra/Test.MT.1280.md:25`
- Not files touched for this change. Verify with `git log` on those files, but likely a lint violation already present on `main`.

### `MaesterTestTags.Tests.ps1` ("Tags" block)
- `PSInvalidCastException: Cannot convert the "Tag = Users" value of type "System.String" to type "System.Management.Automation.ScriptBlock"`
- Looks like a real bug in a test file using `Tag = Users` without proper quoting/array syntax in a Pester block header.
- Check whether it's related to any file edited on this branch; if not, likely pre-existing.

## 3. Likely caused by local changes — action needed before committing

### `FileEncoding.Tests.ps1`
- Flags `powershell/tests/functions/Invoke-MtPackGitHubRequest.Tests.ps1` as missing a UTF-8 BOM.
- Fix:
  ```powershell
  $c = Get-Content 'powershell/tests/functions/Invoke-MtPackGitHubRequest.Tests.ps1' -Raw
  Set-Content 'powershell/tests/functions/Invoke-MtPackGitHubRequest.Tests.ps1' -Value $c -NoNewline -Encoding utf8BOM
  ```

### `Golden.Tests.ps1`
- `SelectedCount` drifted from 609 (committed) to 616 (current).
- Likely caused by new/edited test attributes (e.g., MT.1283) changing what a default run selects.
- Fix (only if the new count is intentional):
  ```powershell
  ./build/golden/Export-MtGoldenFixture.ps1
  ```
  then commit the diff. Confirm the count change is expected before regenerating.

### `TestBuilderData.Tests.ps1`
- Diff shows expected `"key": "UserFlow"` vs actual `"key": "Agent"` — generated website data is stale relative to a registry/schema change.
- Fix:
  ```powershell
  ./build/website/Update-MtTestBuilderData.ps1
  ```
  then commit `website/src/data/test-builder.json`.

## Recommended next steps

1. Run `git status` / `git diff` to see exactly what's modified on this branch, and correlate items in section 3 to those changes.
2. Regenerate golden/test-builder artifacts only if the underlying change is intentional; otherwise these indicate an unintended side effect of the test edit.
3. Confirm items in section 2 predate this branch:
   ```powershell
   git log -1 origin/main -- tests/maester/entra/Test.MT.1279.md tests/maester/entra/Test.MT.1280.md
   ```
   and check the tags test file history. Consider filing/checking an existing issue rather than fixing them as part of this change.
