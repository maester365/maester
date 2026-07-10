# Build-MaesterPackage

Builds the scope-safe Maester release package under `./publish/Maester/`.
Unlike the consolidated optimization artifact, this package preserves individual
PowerShell source files and their script-scope boundaries.

## Usage

```powershell
./build/Build-MaesterPackage.ps1
./build/Test-MaesterPackageOutput.ps1
Import-Module ./publish/Maester/Maester.psd1 -Force
```

## Package contents

The script copies the reviewed module source from `./powershell` and adds the
security test suites from `./tests` under `maester-tests/`. It excludes local
generated output and operating-system metadata such as `.DS_Store`.

Both source trees remain unchanged. The output directory is cleaned and recreated
on each run, and paths outside the repository are rejected as a deletion safeguard.

## Validation

`Test-MaesterPackageOutput.ps1` checks the package layout, manifest version,
exported command count, and comment-based help. It also runs an empty DLP result
through `Invoke-Maester` and fails if PowerShell function definitions appear in
the report detail.
