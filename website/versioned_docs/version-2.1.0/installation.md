---
title: Installation guide
---

- Install the **Maester** PowerShell module, Pester, and the out-of-the-box tests.

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

To learn more about the `Invoke-Maester` cmdlet including how to filter tests, and customize the run of the Pester configuration, see the [Invoke-Maester](commands/Invoke-Maester.mdx) documentation.

## Optional modules and permissions

Maester includes optional [CISA](tests/cisa/) tests that require additional permissions and modules to run. These optional tests are skipped if the modules are not installed or there is no active connection.

### Installing Azure, Exchange Online, and Teams modules

```powershell
Install-Module Az.Accounts, ExchangeOnlineManagement, MicrosoftTeams -Scope CurrentUser
```

> The Security & Compliance PowerShell module is dependent on the ExchangeOnlineManagement `Connect-IPPSSession` cmdlet.

### Connecting to Azure, Exchange, and other services

In order to run all the CISA tests, you need to connect to the Azure, Exchange Online, and other modules.

For a more detailed introduction to these concepts see the [Connect-Maester](connect-maester/readme.md) documentation.

Run the following command to interactively connect to the Azure, Microsoft Graph, Exchange Online, and other modules. A sign-in window will appear for each module.

```powershell
Connect-Maester -Service All
```

### Permissions

Exchange Online implements a [role-based access control model](https://learn.microsoft.com/exchange/permissions-exo/permissions-exo). The controls these cmdlets test require minimum roles of either of the following:

* View-Only Configuration OR
* O365SupportViewConfig

### Installing Azure DevOps PowerShell module

```powershell
Install-Module ADOPS -Scope CurrentUser
```

### Connecting to Azure DevOps

In order to run all the Azure DevOps tests, you need to connect to Azure DevOps.

This is currently not included as part of [Connect-Maester](connect-maester/readme.md) and must be called separately. Run the following command to interactively connect using the Azure DevOps modules. A sign-in window will appear.

Example with PowerShell variable
```powershell
$AdoPSAllowInsecureAPIs = $true
Import-Module ADOPS
Connect-ADOPS -Organization <Name Of DevOps Organization>
```

Example with ArgumentList
```powershell
Import-Module ADOPS -ArgumentList $true
Connect-ADOPS -Organization <Name Of DevOps Organization>
```

> Note: Some of the API endpoints used for Azure DevOps tests use unsupported endpoints.
To allow usage of unsupported endpoints, you must set `$true` in the argumentlist when importing the module, or set a PowerShell variable called "$AdoPSAllowInsecureAPIs" to `$true` before importing the module.
Reference: https://github.com/AZDOPS/AZDOPS/issues/248

### Permissions

Azure DevOps implements a [role-based access control model](https://learn.microsoft.com/en-us/azure/devops/organizations/security/permissions?view=azure-devops&tabs=preview-page). The controls these cmdlets test require the minimum role of:

* Project-Scoped Users at Organization level

## Next Steps

- Monitoring with Maester
  - [Set up Maester on GitHub](monitoring/github.md)
  - [Set up Maester on Azure DevOps](monitoring/azure-devops.md)
  - [Set up Maester on Azure Container App Jobs](monitoring/azure-container-app-job.md)
- Alerting with Maester
  - [Set up Maester email alerts](alerts/email.md)
  - [Set up Maester Teams alerts](alerts/teams.md)
  - [Set up Maester Slack alerts](alerts/slack.md)
- [Writing Custom Tests](writing-tests/index.mdx)
