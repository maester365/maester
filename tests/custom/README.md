# Custom tests

Put your own Maester tests in this folder. The tests that ship with Maester run from
the module itself, so you do not need a copy of them here: updating the module updates
them.

## Running

```powershell
Invoke-Maester                  # built-in tests plus the custom tests in this folder
Invoke-Maester -SkipBuiltIn     # only the custom tests
```

## Writing a test

Maester runs two kinds of custom test from this folder:

- **Pester tests** (`*.Tests.ps1`): `Describe` / `It` blocks, as in Maester 2.x. Name each
  `It` as `<ID>: <title>`, for example `It 'CONTOSO.1001: Guest access is restricted'`,
  so that the test can be selected with `-TestId` and configured by ID. Pester must be
  installed to run them.
- **Native tests** (`Test.<ID>.ps1` with a `[MaesterTest(...)]` function), the format of
  the built-in tests from Maester 3.0. See https://maester.dev/docs/next/writing-tests.

Use your own ID prefix (for example `CONTOSO.`). IDs that start with `MT.`, `CIS.`,
`CISA.`, `EIDSCA.`, `ORCA.`, `AD-`, `AZDO.` or `MT1060.` belong to the built-in tests.

## Changing a built-in test

Do not copy a built-in test here to change it: a copy with a built-in ID is not run.
Instead, in `maester-config.json`:

- turn a test off with `{ "Id": "MT.1005", "Enabled": false, "Reason": "..." }` in
  `TestSettings`;
- change its severity with `"Severity"`;
- or copy it under your own ID and turn the built-in one off.
