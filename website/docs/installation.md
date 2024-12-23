---
title: Installation guide
---

- Install the **Maester** PowerShell module, Pester, and the out of the box tests.

```powershell
Install-Module Pester -SkipPublisherCheck -Force -Scope CurrentUser
Install-Module Maester -Scope CurrentUser

md maester-tests
cd maester-tests
Install-MaesterTests
```

- Sign into your Microsoft 365 tenant and run the tests.

```powershell
Connect-Maester
Invoke-Maester
```

## Invoke-Maester

To learn more about the `Invoke-Maester` cmdlet including how to filter tests, and customize the run of the Pester Configuration see the [Invoke-Maester](/docs/commands/Invoke-Maester) documentation.


## Optional modules and permissions

Maester includes optional [CISA](tests/cisa/) tests that require additional permissions and modules to run. These optional tests are skipped if the modules are not installed or there is no active connection.

### Installing Azure and Exchange Online modules

```powershell
Install-Module Az -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

> The Security & Compliance PowerShell module is dependent on the ExchangeOnlineManagement `Connect-IPPSSession` cmdlet.

### Connecting to Azure, Exchange and other services

In order to run all the CISA tests, you need to connect to the Azure, Exchange Online, and other modules.

For a more detailed introduction to these concepts see the [Connect-Maester](/docs/connect-maester) documentation.

Run the following command to interactively connect to the Azure, Exchange Online, and other modules. A sign in window will appear for each module.

```powershell
Connect-Maester -Service All
```

### Permissions

Exchange Online implements a [role-based access control model](https://learn.microsoft.com/exchange/permissions-exo/permissions-exo). The controls these cmdlets test, require minimum roles of either of the following:

* View-Only Configuration OR
* O365SupportViewConfig

## Next Steps

- Monitoring with Maester
  - [Set up Maester on GitHub](/docs/monitoring/github)
  - [Set up Maester on Azure DevOps](/docs/monitoring/azure-devops)
  - [Set up Maester on Azure Container App Jobs](/docs/monitoring/azure-container-app-job)
  - [Set up Maester email alerts](/docs/monitoring/email)
  - [Set up Maester Slack alerts](/docs/monitoring/slack)
- [Writing Custom Tests](/docs/writing-tests)
