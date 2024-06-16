# Maester Tests

This folder contains the tests that Maester will run to validate your environment. The tests are organized into the following folders:

- **Custom**: Place your custom Pester tests in this directory. The file name should end with `.Tests.ps1`.
- **CISA**: Contains the tests that verifies the tenant’s configuration conforms to the policies described in the Secure Cloud Business Applications ([SCuBA](https://cisa.gov/scuba)) Security Configuration Baseline [documents](https://github.com/cisagov/ScubaGear/blob/main/baselines/README.md).
- **EIDSCA**: Contains tests based on the [Entra ID Security Config Analyzer](https://maester.dev/docs/tests/eidsca/).
- **Maester**: Contains the tests that are built by the Maester team with contributions from the community. To learn more about the tests see [Maester Tests](https://maester.dev/docs/tests/maester).

## Running Maester

To run the tests in this folder run the following PowerShell commands. To learn more see [maester.dev](https://maester.dev).

```powershell
Connect-Maester
Invoke-Maester
```

## Keeping your Maester tests up to date

The Maester team will add new tests over time. To get the latest updates, use the commands below to update this folder with the latest tests.

- Update the `Maester` PowerShell module to the latest version and load it.
- Change to the folder that has the tests.
- Run `Update-MaesterTests`.

```powershell
Update-Module Maester -Force
Import-Module Maester
Update-MaesterTests
```
