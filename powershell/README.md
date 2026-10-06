## PowerShell Summary

The `powershell` directory holds the source of the Maester PowerShell module. The security checks that ship with
Maester are not here: they are native tests in the repository's [`tests`](../tests) folder, and the build defines
their functions in the module.

Maester 3.0 requires PowerShell 7.4 or later (the `Core` edition).

## Folder Structure

#### assets/
Templates and data files used by the module, including the engine's data tables:

- `MaesterTestSchema.psd1` - the properties of the `[MaesterTest]` attribute and their rules.
- `MaesterServiceRegistry.psd1` - the services a test can declare in `Service`, and how each is probed.
- `MaesterLicenseTable.psd1` - the licence tokens accepted in `CompatibleLicense` and the plan and SKU IDs they match.
- `MaesterParameterKinds.psd1` - the kinds a test parameter can declare with `[MaesterParameter(Kind = ...)]`.
- `MaesterSettings.psd1` - the global settings Maester knows, with their defaults (read by `Get-MtSetting`).
- `Maester.LegacyIds.json` - previous IDs of built-in tests, used to recognise stale 2.x copies.
- `templates/` - the files `Install-MaesterTests` writes.

#### internal/
Internal functions that are not exported. `internal/engine/` holds the test engine: discovery
(`Read-MtNativeTest`, `Get-MtNativeTestInventory`), configuration (`Resolve-MtRunConfig`), selection and
applicability (`Resolve-MtSelection`, `Resolve-MtNativePlan`), execution (`Invoke-MtNativePlan`), the Pester
provider for Pester-format custom tests, and the NUnit/JUnit writer. `internal/checks/` holds helpers shared by
several built-in tests.

#### lib/
`Maester.Engine.dll`, the compiled scheduling core and the `[MaesterTest]` and `[MaesterParameter]` attribute
types, built from [`src/Maester.Engine`](../src/Maester.Engine) and committed. You need the .NET SDK only to change
the engine.

#### public/
Exported functions, such as **Invoke-Maester**, **Invoke-MtTest**, **Get-MtTest** and **New-MtTest**. Only these
functions are part of the public surface; the check functions behind the built-in tests are internal from 3.0.

#### tests/
Unit tests for the module itself, run with `./powershell/tests/pester.ps1`. These are different from the security
checks in the repository's `tests` folder.

## Module structure

### Maester.psd1
This is the PowerShell module manifest file for the Maester project. It contains metadata about the module, such as its version, author, and dependencies.

### Maester.psm1
This is the PowerShell module file for the Maester project. In a source checkout it loads the functions under
`internal/` and `public/`, then defines the built-in native tests from `../tests`, so `Import-Module
./powershell/Maester.psd1` gives you a working module without a build. The build (`./build/Build-MaesterModule.ps1`)
concatenates the same sources into one file and writes the test catalog (`Maester.TestCatalog.json`) and the
Markdown bundle (`Maester.TestMetadata.json`) beside it.
