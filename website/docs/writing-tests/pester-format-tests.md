---
title: Pester-format tests
sidebar_position: 4
description: Custom tests written with Pester keep running in Maester 3.0. How they run, what they need, and how to convert them to native tests.
---

# Pester-format tests (still supported)

Before 3.0 every Maester test was a Pester `It` block in a `*.Tests.ps1` file. Custom tests written that way
keep running in Maester 3.0: Maester calls the real `Invoke-Pester` for them, and their rows appear in the same
report as the native tests. New tests should be [native tests](./index.mdx). This page covers what you need to
keep your existing Pester tests working and how to convert them.

## What you need

- **Pester 5.7.1 or later**, including 6.x. Maester no longer installs Pester or depends on it, and imports it
  only when the run includes Pester-format tests.

  ```powershell
  Install-Module Pester -MinimumVersion 5.7.1 -Scope CurrentUser -SkipPublisherCheck
  ```

- If the run includes Pester-format tests and no suitable Pester is installed, those tests are not run. Each one
  the run would have selected becomes an `Error` row with reason `PesterNotAvailable` and an install hint,
  Maester writes one warning, and the native tests still run and report normally.

The Pester 3.4 that ships with Windows is never used.

## How Pester-format tests run

- Maester finds `*.Tests.ps1` files under `-Path`, the same folder it searches for native tests, and runs them
  with one `Invoke-Pester` call after the native tests.
- The test files run inside the Maester module, as in 2.x, so `BeforeAll`, `BeforeDiscovery`, `-ForEach`,
  `-Skip`, `Context`, `Set-ItResult` and every `Should` operator work as before. Even with `-DryRun`, Pester
  discovery runs, so `BeforeDiscovery` and `Describe`-level code execute.
- The test ID is the text before the first colon of the `It` name: `It 'CONTOSO.1001: Guest access is
  restricted'` has the ID `CONTOSO.1001`. Name your tests this way so they can be selected with `-TestId`,
  configured by ID in `TestSettings`, and recognised in the result.
- Selection by ID, `TestSettings[].Enabled` and `Selection.DefaultAction = Skip` apply to Pester tests too.
  Maester reads the files statically and excludes the deselected `It` blocks by line; they appear as `NotRun`
  rows with a reason code. A test whose name is built at run time (for example with `<_>` or `$_` from
  `-ForEach`) can be selected only as a whole, through the literal start of its name.
- `Severity` comes from a `TestSettings` row in the config, else, when the test calls
  `Add-MtTestResultDetail`, from its `-Severity` or a `Severity:<level>` tag, as in 2.x.
- Rows from Pester tests have `Format = Pester` in the result. They keep the 2.x result rules; for example a
  failed `Should` is `Failed`.

### Copies of built-in tests are not run

A Pester test whose ID is the ID of a test that ships with Maester, a previous ID of one (such as the 2.x
`MS.AAD.7.1` form of a CISA ID), or the ID of a built-in that was retired, is a stale copy, and so is a test
whose name starts with the ID of a built-in family and a dot (`MT.1024.`, `MT.1033.`, `MT.1034.`, `MT.1059.`,
`MT1060.`). A stale copy is not run and
produces no row, wherever it is, including under `custom/`. Maester writes one warning naming the files, and
lists the tests under `Selection.Superseded` in the result. `Update-MaesterTests` deletes files that contain
only such copies (outside `custom/`).

Copying a built-in test into `custom/` to change it no longer works. Set its parameters or severity in the
[run configuration](../configuration/run-configuration.md), or copy it under your own ID and disable the
built-in.

### Calling built-in check functions

In 2.x a custom test could call a check function such as `Test-MtCaMfaForRiskySignIn` directly. In 3.0 those
functions are internal and no longer check their own connections. Run the check through the engine instead:

```powershell
Describe 'Contoso' -Tag 'Contoso' {
    It 'CONTOSO.1003: Risky sign-ins require MFA' {
        $row = Invoke-MtTest -Id MT.1012
        $row.Result | Should -Be 'Passed'
    }
}
```

If Maester 2.x is still installed, calling a 2.x function makes PowerShell load the 2.x module into the session.
Maester detects this, removes it again and warns. Remove 2.x with
`Uninstall-Module Maester -MaximumVersion 2.99.99 -AllVersions`.

## -PesterConfiguration

`Invoke-Maester -PesterConfiguration` still exists. It accepts a `[PesterConfiguration]` object (from
`New-PesterConfiguration`) or a hashtable, so a script can pass it without loading Pester first. Maester works on
a copy, so you can reuse the same object for several runs:

```powershell
Invoke-Maester -PesterConfiguration @{
    Run    = @{ Path = './maester-tests' }
    Filter = @{ Tag = 'CA'; ExcludeTag = 'App' }
}
```

Some options also apply to native tests:

| Option | Effect in 3.0 |
| --- | --- |
| `Run.Path` | Used as `-Path` when `-Path` is not given. |
| `Filter.Tag` | Used as `-Tag` when `-Tag` is not given. Applies to native and Pester tests. |
| `Filter.ExcludeTag` | Added to `-ExcludeTag`, `Selection.ExcludeTag` and the default exclusions. (2.x discarded it whenever a default exclusion applied.) |
| `TestResult.Enabled`, `.OutputPath`, `.OutputFormat` | Maester writes one NUnit or JUnit file for native and Pester rows, unless `Output.TestResult` in the run configuration already asks for one. See [Result schema](../result-schema.md#ci-test-results-nunit-and-junit-xml). |
| `Output.Verbosity` | Replaced by `-Verbosity`. |
| `Run.ExcludePath`, `Filter.ExcludeLine` | Kept, and Maester's own exclusions are added. |
| `Run.PassThru` | Always on. |
| `Run.Parallel`, `Run.FailOnNullOrEmptyForEach` (Pester 6) | Always off: parallel Pester runs outside the module and would lose every result detail. |
| Everything else | Passed to Pester for the Pester-format tests. |

## Converting to native tests

`Convert-MtTest` converts the Pester-format tests in a folder to native tests. It reads the files' syntax trees
and never runs them.

```powershell
Convert-MtTest -Path ./custom -WhatIf                      # what would be converted
Convert-MtTest -Path ./custom | Format-Table Id, Status, Notes
Convert-MtTest -Path ./custom -OutputPath ./custom/native  # write the native files elsewhere
```

For each `It` block it writes `Test.<ID>.ps1` and `Test.<ID>.md` and returns one report row with `Id`,
`Source` (file and line), `Output`, `Status` (`Converted`, `NeedsReview` or `Skipped`) and `Notes`.

What it handles:

- **The split-file pattern**: an `It` whose body is one call to a function defined in a `.ps1` file in the same
  folder, checked with `Should -Be $true` / `-BeTrue` (or `$false` / `-BeFalse`). The function becomes the
  native test. A leading `if (-not (Test-MtConnection X)) { ... return }` guard becomes `Service = 'X'`, and an
  outer `try`/`catch` that only reports `-SkippedBecause Error` is removed. When the `It` passes arguments or
  asserts `$false`, the function is kept as a helper and a small test function calls it.
- **Inline tests**: the `It` body becomes the function body, with a trailing `<value> | Should -Be $true`
  rewritten to `return (<value>)`. Other assertions and `Set-ItResult` are kept with a `TODO` comment, and the
  row is `NeedsReview`.
- The `It` name gives the ID and title, the `Describe` name the category, and the `Describe`, `Context` and `It`
  tags become `Tag` (`Preview` and `LongRunning` become the flags). A `Severity:<level>` tag sets `Severity`,
  else `Medium`. A `See https://...` suffix that does not point to maester.dev becomes `HelpUrl`.
- The Markdown comes from the function's `.md` file, else from `-Description` in the code, else the title; a
  generated `.md` is noted in the report so you can add remediation steps. The `<!--- Results --->` footer is
  added when missing.

What it leaves to you:

- A test whose name is built at run time (from `-ForEach` or `-TestCases`) is `Skipped`. Rewrite it by hand as a
  [family](./index.mdx#families-one-test-several-results) with an `InstanceSource` function.
- Data prepared in `BeforeDiscovery` or `BeforeAll` is not available to the converted test; the report notes
  it.
- An ID that is not valid for native tests is `Skipped`. An ID without a prefix (such as `CT0001`) converts, and
  the report suggests one.
- The guessed `Service` is a suggestion when the code had no `Test-MtConnection` guard; check it.

Each written file is validated, and validation problems turn the row into `NeedsReview`. Run
`Get-MtTest -Path ./custom` and `Invoke-MtTest -Path ./custom/Test.<ID>.ps1` on the result.

The original `*.Tests.ps1` files are not changed. Once a native test exists with the same ID, the Pester test
with that ID no longer runs: the native test runs instead, and the Pester test is listed under
`Selection.Superseded`. Delete the
Pester file when you are satisfied with the native version.

## Pester 6 notes

Maester supports Pester 6 for custom tests. Three Pester 6 changes can affect your tests: `-Tag None` is
reserved by Pester, `Set-ItResult -Pending` is removed, and non-string values in `<...>` name templates render
differently.
