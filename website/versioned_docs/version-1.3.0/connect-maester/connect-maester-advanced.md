---
sidebar_label: Connect-Maester Advanced
sidebar_position: 2
title: Connect-Maester - Advanced
---

# Connect-Maester Advanced

import CreateEntraApp from '../sections/create-entra-app.md';

## Overview

There are two main methods of authenticating sessions for use with Maester:

* Within the Maester module
* Within the respective modules for the tests

### Module Integrations

The Maester module integrates with the following modules:

* Microsoft.Graph.Authentication
* Az.Accounts
* ExchangeOnlineManagement
* MicrosoftTeams

### Within the Maester module

:::tip
Recommended for interactive use
:::

The Maester module includes [`Connect-Maester`](/docs/commands/Connect-Maester) to provide coverage for common scenarios. The parameter set options afford a user of the module the ability to test with common interactive methods. The Microsoft Graph API is the default authentication service, and more specifically the Microsoft Graph PowerShell SDK. Coverage for tests shipping with Maester have at least one option available in general.

> The objective of the Maester module is not to replace or consolidate the authentication options across the many possible testing sources.

### Within the respective modules for the tests

**Recommended for automation use**

The Maester module provides a framework for creating, executing, and reporting on configuration state using tests. Each test can rely on one or more sources to perform validation. Each source a test validates may be available without authentication (e.g., Domain Name System) or may require authentication to a sepcific environment (e.g., Microsoft Graph API).

The recommendation for authenticating to modules necessary to support tests for the most extensibility is to authentcate within those source modules and running `Invoke-Maester` with the `-SkipGraphConnect` property.

As an example, connecting to the Microsoft Graph PowerShell SDK module as a managed identity and then running Maester.

> Running `Connect-Maester` is not required to use `Invoke-Maester`.

```powershell
Connect-MgGraph -Identity -NoWelcome
Invoke-Maester -SkipGraphConnect -NonInteractive
```

The following diagram provides a general overview of command dependency relationships. You can extend Maester with your own tests that leverage other modules as may be beneficial. There is no dependency for your own tests to rely on the `Connect-Maester` capabilities.

```mermaid
graph TD;
  Connect-Maester-->Microsoft.Graph.Authentication;
  Connect-Maester-->Az.Accounts;
  Connect-Maester-->ExchangeOnlineManagement;
  Connect-Maester-->a[Additional Modules];
  Microsoft.Graph.Authentication-->Get-MgContext;
  Microsoft.Graph.Authentication-->Get-MgEnvironment;
  Microsoft.Graph.Authentication-->Invoke-MgGraphRequest;
  Az.Accounts-->Get-AzContext;
  Az.Accounts-->Invoke-AzRestMethod;
  ExchangeOnlineManagement-->Get-ConnectionInformation;
  ExchangeOnlineManagement-->Get-EXOMailbox;
  ExchangeOnlineManagement-->Get-MtExo;
  Get-MtExo-->Get-AcceptedDomain;
  Get-MtExo-->o[Other Commands];
```

You can [write tests](/docs/writing-tests) that expand Maester to validate the configuration state of infrastructure in the cloud, on-premises, and entirely unrelated to Microsoft products.

For use with the Maester tests the following provides an overview of creating the necessary service principal.

<CreateEntraApp/>

## Authenticating Across Tenants

You may have a need to use Maester with multiple tenanats. The Maester tests enable you to accomplish this, but it is best to authenticate within the respective modules for the tests you wish to run.

### Microsoft Graph PowerShell SDK Module

The Microsoft Graph PowerShell SDK Module provides many [options for authenticating](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands). Below is an example of using a X.509 Certificate private key file, `$cert`, to authenticate to `$tenantId` as the `$applicationId` service principal.

```powershell
#$applicationId = "xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx"
#tenantId = "xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx"
#$b64 = Get-Content .\path\to\cert.pfx -Raw
#$b64 = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $applicationDisplayName -AsPlainText
#$bytes = [Convert]::FromBase64String($b64)
#$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)

Connect-MgGraph -AppId $applicationId -Certificate $cert -TenantId $tenantId -NoWelcome
```

### Microsoft Azure Accounts PowerShell Module

The Microsoft Azure Accounts PowerShell Module provides many [options for authenticating](https://learn.microsoft.com/en-us/powershell/azure/authenticate-noninteractive). Below is an example of using a X.509 Certificate private key file to authenticate to `$tenantId` as the `$applicationId` service principal.

```powershell
#$applicationId = "xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx"
#tenantId = "xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx"

Connect-AzAccount -ServicePrincipal -ApplicationId $applicationId -TenantId $tenantId -CertificatePath /cert.pfx
```

### Microsoft Exchange Online and Security & Compliance PowerShell Modules

The Microsoft Exchange Online and Security & Compliance PowerShell Modules provide many [options for authenticating](https://learn.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2). Below is an example of using a X.509 Certificate private key file, `$cert`, to authenticate to `$tenantId` as the `$applicationId` service principal.

> These modules don't reference the tenant ID GUID for authentication, they instead use the tenant's Microsoft Online Email Routing Address (MOERA).

```powershell
#$applicationId = "xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx"
#$b64 = Get-Content .\path\to\cert.pfx -Raw
#$b64 = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $applicationDisplayName -AsPlainText
#$bytes = [Convert]::FromBase64String($b64)
#$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
#$domains = Invoke-MgGraphRequest -Uri https://graph.microsoft.com/v1.0/domains
#$moera = ($domains.value|?{$_.isInitial}).id

Connect-ExchangeOnline -Certificate $cert -AppID $applicationId -Organization $moera -ShowBanner:$false
Connect-IPPSSession -Certificate $cert -AppID $applicationId -Organization $moera -ShowBanner:$false
```

### Microsoft Teams PowerShell Module

The Microsoft Teams PowerShell Module supports both interactive and non-interactive [authentication methods](https://learn.microsoft.com/powershell/module/teams/connect-microsoftteams?view=teams-ps). For interactive sessions, you can use the standard login prompt. For non-interactive use, such as in automation scenarios, service principal authentication is recommended.

```powershell
# Interactive
Connect-MicrosoftTeams

# Non-Interactive (Service Principal)
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("C:\exampleCert.pfx",$password)
Connect-MicrosoftTeams -Certificate $cert -ApplicationId $applicationId -TenantId $tenantId
```
