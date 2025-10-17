---
sidebar_label: Azure Web App with Bicep
sidebar_position: 8
title: Azure Web App
---
import GraphPermissions from '../sections/permissions.md';
import PrivilegedPermissions from '../sections/privilegedPermissions.md';

# <IIcon icon="devicon:azure" height="48" /> Setup Maester in Azure Web App using Azure Bicep

This guide will demonstrate how to get Maester running on an Azure Web App and provide an Azure Bicep template for automated deployment
-  This setup will allow you to perform security configuration checks on your Microsoft tenant by accessing the Azure Web App, which is protected with Entra ID Authentication through the Bicep deployment.🔥

## Why Azure Web App & Azure Automation & Azure Bicep?

Azure Web Apps provide the functionality to host your own websites. By running Maester in an interactive web app, you can easily check the security recommendations for your organization. Azure Automation generates a new Maester report every Monday, Wednesday, and Friday, which is then uploaded to the Azure Web App using Managed Identities.

 Azure Bicep is a domain-specific language that uses declarative syntax to deploy Azure resources. It simplifies the process of defining, deploying, and managing Azure resources. Here’s why Azure Bicep stands out:
- **Simplified Syntax**: Bicep provides concise syntax, reliable type safety, and support for reusing code.easier to read.
- **Support for all resource types and API versions**: Bicep immediately supports all preview and GA versions for Azure services.
- **Modular and Reusable**: Bicep enables the creation of modular templates that can be reused across various projects, ensuring consistency and minimizing duplication.

![Screenshot of the Bicep Solution](assets/azurewebapp-bicep-overview.png)

### Pre-requisites

- If this is your first time using Microsoft Azure, you must set up an [Azure Subscription](https://learn.microsoft.com/azure/cost-management-billing/manage/create-subscription) so you can create resources and are billed appropriately.
- You must have the **Global Administrator** role in your Entra tenant. This is so the necessary permissions can be consented to the Managed Identity.
- You must also have Azure Bicep & Azure CLI installed on your machine, this can be easily done with, using the following commands:

```PowerShell
winget install -e --id Microsoft.AzureCLI
winget install -e --id Microsoft.Bicep
```

## Template Walkthrough
This section will guide you through the templates required to deploy Maester on Azure Automation Accounts. Depending on your needs, this can be done locally or through CI/CD pipelines.
- For instance, using your favorite IDE such as VS Code.
- Alternatively, through Azure DevOps.

To be able to declare Microsoft Graph resources in a Bicep file, you need to enable the Bicep preview feature and specify the Microsoft Graph Bicep type versions, by configuring ```bicepconfig.json```

```json
{
    "experimentalFeaturesEnabled": {
        "extensibility": true
    },
    // specify an alias for the version of the v1.0 dynamic types package you want to use
    "extensions": {
      "microsoftGraphV1": "br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:1.0.0"
    }
}
```

The ```main.bicepparam``` template defines our input parameters, such as the environment, customer, location, and app roles for the Managed Identity (MI).

```bicep
using 'main.bicep'

// Defing our input parameters
param __env__ = 'prod'
param __cust__ = 'ct'
param __location__ = 'westeurope'
param __defaultTenantName__ = 'contoso.onmicrosoft.com'

param __maesterAppRoles__ = [
  'DeviceManagementConfiguration.Read.All'
  'DeviceManagementManagedDevices.Read.All'
  'Directory.Read.All'
  'DirectoryRecommendations.Read.All'
  'IdentityRiskEvent.Read.All'
  'Policy.Read.All'
  'Policy.Read.ConditionalAccess'
  'PrivilegedAccess.Read.AzureAD'
  'Reports.Read.All'
  'RoleEligibilitySchedule.Read.Directory'
  'RoleManagement.Read.All'
  'SecurityIdentitiesSensors.Read.All'
  'SecurityIdentitiesHealth.Read.All'
  'SharePointTenantSettings.Read.All'
  'ThreatHunting.Read.All'
  'UserAuthenticationMethod.Read.All'
]

param __maesterAutomationAccountModules__ = [
  {
    name: 'Maester'
    uri: 'https://www.powershellgallery.com/api/v2/package/Maester'
    version: '1.3.0'
  }
  {
    name: 'Microsoft.Graph.Authentication'
    uri: 'https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Authentication'
    version: '2.30.0'
  }
  {
    name: 'Pester'
    uri: 'https://www.powershellgallery.com/api/v2/package/Pester'
    version: '5.7.1'
  }
  {
    name: 'NuGet'
    uri: 'https://www.powershellgallery.com/api/v2/package/NuGet'
    version: '1.3.3'
  }
  {
    name: 'PackageManagement'
    uri: 'https://www.powershellgallery.com/api/v2/package/PackageManagement'
    version: '1.4.8.1'
  }
  {
    name: 'ExchangeOnlineManagement'
    uri: 'https://www.powershellgallery.com/api/v2/package/ExchangeOnlineManagement'
    version: '3.9.0'
  }
  {
    name: 'MicrosoftTeams'
    uri: 'https://www.powershellgallery.com/api/v2/package/MicrosoftTeams'
    version: '7.3.1'
  }
]
```

The ```main.bicep``` template serves as the entry point for our Bicep configuration. It defines the parameters and variables used across the various modules.

```bicep
metadata name = 'Maester Automation as Code <3'
metadata description = 'Deploys Maester Automation Account with modules and runbook for automated reports on Mon, Wed, Fri via Azure Web App with Entra ID Auth'
metadata owner = 'Maester'
targetScope = 'subscription'

extension microsoftGraphV1

@description('Defing our input parameters')
param __env__ string
param __cust__ string
param __location__ string
param __defaultTenantName__ string
param __maesterAppRoles__ array
param __maesterAutomationAccountModules__ array

@description('Defining our variables')
var _maesterAutomationVariables_ = [
  {
    name: 'appName'
    value: format('"{0}"', _appServiceName_)
    isEncrypted: false
  }
  {
    name: 'resourceGroupName'
    value: format('"{0}"', _maesterResourceGroupName_)
    isEncrypted: false
  }
  {
    name: 'tenantId'
    value: format('"{0}"', tenant().tenantId)
    isEncrypted: false
  }
  {
    name: 'tenant'
    value: format('"{0}"', __defaultTenantName__)
    isEncrypted: false
  }
  {
    name: 'enableTeamsTests'
    value: 'false'
    isEncrypted: false
  }
  {
    name: 'enableExchangeTests'
    value: 'false'
    isEncrypted: false
  }
  {
    name: 'enableComplianceTests'
    value: 'false'
    isEncrypted: false
  }
]

var _shortLocation_ = substring(__location__, 0, 6)
var _maesterResourceGroupName_ = 'rg-maester-${__env__}-${_shortLocation_}-001'
var _maesterAutomationAccountName_ = 'aa-maester-${__env__}-${_shortLocation_}-001'
var _suffix_ = substring(uniqueString(subscription().id), 0, 2)
var _maesterStorageAccountName_ = 'sa${__cust__}${_suffix_}${__env__}001'
var _maesterStorageBlobName_ = 'maester'
var _maesterStorageBlobFileName_ = 'maester.ps1'
var _appServiceName_ = 'app-maester-${_suffix_}-${__env__}-${_shortLocation_}-001'
var _appServicePlanName_ = 'asp-maester-${__env__}-${_shortLocation_}-001'

@description('Resource Group Deployment')
resource maesterResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: _maesterResourceGroupName_
  location: __location__
}

@description('Module Deployment')
module modAutomationAccount './modules/aa.bicep' = {
  name: 'module-automation-account-deployment'
  params: {
    __location__: __location__
    _maesterAutomationVariables_: _maesterAutomationVariables_
    _appServiceName_: _appServiceName_
    _maesterResourceGroupName_: _maesterResourceGroupName_
    _maesterAutomationAccountName_: _maesterAutomationAccountName_
    __maesterAutomationAccountModules__: __maesterAutomationAccountModules__
    _maesterStorageAccountName_: _maesterStorageAccountName_
    _maesterStorageBlobName_: _maesterStorageBlobName_
    _maesterStorageBlobFileName_: _maesterStorageBlobFileName_
  }
  scope: maesterResourceGroup
}

module modAutomationAccountAdvanced './modules/aa-advanced.bicep' = {
  name: 'module-automation-account-advanced-deployment'
  params: {
    __location__: __location__
    __ouMaesterAutomationMiId__: modAutomationAccount.outputs.__ouMaesterAutomationMiId__
    __ouMaesterScriptBlobUri__: modAutomationAccount.outputs.__ouMaesterScriptBlobUri__
    _maesterAutomationAccountName_: _maesterAutomationAccountName_
    __maesterAppRoles__:  __maesterAppRoles__

  }
  scope: maesterResourceGroup
}

module modAppService './modules/app-service.bicep' = {
  name: 'module-app-service-deployment'
  params: {
    __location__: __location__
    __ouMaesterAutomationMiId__: modAutomationAccount.outputs.__ouMaesterAutomationMiId__
    _appServiceName_: _appServiceName_
    _appServicePlanName_: _appServicePlanName_
  }
  scope: maesterResourceGroup
}
```

The ```aa.bicep``` module-file, automates the deployment of the Maester Azure Automation Account, a Storage Account, a container and uploads the Maester script to the Blob Container, which will be later used as input for our PowerShell runbook for the automation account to generate a security report.

```bicep

param __location__ string
param _maesterAutomationVariables_ array
param _appServiceName_ string
param _maesterResourceGroupName_ string
param _maesterAutomationAccountName_ string
param __maesterAutomationAccountModules__ array
param _maesterStorageAccountName_ string
param _maesterStorageBlobName_ string
param _maesterStorageBlobFileName_ string

@description('Automation Account Deployment')
resource automationAccount 'Microsoft.Automation/automationAccounts@2024-10-23' = {
  name: _maesterAutomationAccountName_
  location: __location__
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

@description('Create Automation Variables')
resource variables 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = [for var in _maesterAutomationVariables_: {
  parent: automationAccount
  name: var.name
  properties: {
    value: var.value
    isEncrypted: var.isEncrypted
  }
}]

resource automationAccountRuntimeEnvironment 'Microsoft.Automation/automationAccounts/runtimeEnvironments@2024-10-23' = {
  parent: automationAccount
  name: 'PowerShell-7.4'
  location: __location__
  properties: {
    runtime: {
      language: 'PowerShell'
      version: '7.4'
    }
    defaultPackages: {
       az: '12.3.0'
       'Azure CLI': '2.64.0' 
    }
  }
}

resource rtePackages 'Microsoft.Automation/automationAccounts/runtimeEnvironments/packages@2024-10-23' = [
  for m in __maesterAutomationAccountModules__: {
    name: m.name
    parent: automationAccountRuntimeEnvironment
    properties: {
      contentLink: {
        uri: m.uri
        version: m.version
      }
    }
  }
]
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: _maesterStorageAccountName_
  location: __location__
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    networkAcls: {
      defaultAction: 'Allow'
    }
  }

}

@description('Create Blob Service')
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
}

@description('Create Blob Container')
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: _maesterStorageBlobName_
  properties: {
    publicAccess: 'Blob'
  }
}

@description('Upload .ps1 file to Blob Container using Deployment Script')
resource uploadScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'deployscript-upload-blob-maester'
  location: __location__
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.26.1'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccount.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: storageAccount.listKeys().keys[0].value
      }
      {
        name: 'CONTENT'
        value: loadTextContent('../pwsh/maester.ps1')
      }
    ]
    arguments: '-appName ${_appServiceName_} -rgName ${_maesterResourceGroupName_}'
    scriptContent: 'echo "$CONTENT" > ${_maesterStorageBlobFileName_} && az storage blob upload -f ${_maesterStorageBlobFileName_} -c ${_maesterStorageBlobName_} -n ${_maesterStorageBlobFileName_}'
  }
  dependsOn: [
    blobContainer
  ]
}

@description('Outputs')
output __ouMaesterAutomationMiId__ string = automationAccount.identity.principalId
output __ouMaesterScriptBlobUri__ string = 'https://${_maesterStorageAccountName_}.blob.${environment().suffixes.storage}/${_maesterStorageBlobName_}/maester.ps1'
```

The ```aa-advanced.bicep``` module file automates the configuration of the Maester Azure Automation Account by setting up role assignments, installing necessary PowerShell modules, creating a runbook, defining a schedule, and associating the runbook with the schedule. This configuration enables Maester to run automatically in Azure according to the specified schedule. This module is separate due to the need for replicating the Managed Service Identity (MSI) in Entra ID. By dividing the configuration into two module files, we can add the API consents 💪🏻


```bicep
extension microsoftGraphV1
param __location__ string
param __maesterAppRoles__ array

param __ouMaesterAutomationMiId__ string
param __ouMaesterScriptBlobUri__ string
param _maesterAutomationAccountName_ string
param __currentUtcTime__ string = utcNow()

@description('Microsoft Graph - Role Assignment Deployment')
resource graphId 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: '00000003-0000-0000-c000-000000000000'
}

@description('Exchange - Role Assignment Deployment')
resource exchangeOnlineId 'Microsoft.Graph/servicePrincipals@v1.0' existing =  {
  appId: '00000002-0000-0ff1-ce00-000000000000'
}

resource managedIdentityRoleAssignment 'Microsoft.Graph/appRoleAssignedTo@v1.0' = [for appRole in __maesterAppRoles__: {
    appRoleId: (filter(graphId.appRoles, role => role.value == appRole)[0]).id
    principalId: __ouMaesterAutomationMiId__
    resourceId: graphId.id
}]

resource managedIdentityRoleAssignmentExchange 'Microsoft.Graph/appRoleAssignedTo@v1.0' =  {
  appRoleId: (filter(exchangeOnlineId.appRoles, role => role.value == 'Exchange.ManageAsApp')[0]).id
  principalId: __ouMaesterAutomationMiId__
  resourceId: exchangeOnlineId.id
}

@description('Existing Automation Account')
resource automationAccount 'Microsoft.Automation/automationAccounts@2024-10-23' existing = {
  name: _maesterAutomationAccountName_
}

@description('Runbook Deployment')
resource automationAccountRunbook 'Microsoft.Automation/automationAccounts/runbooks@2024-10-23' = {
  name: 'runBookMaester'
  location: __location__
  parent: automationAccount
  properties: {
    runbookType: 'PowerShell'
    runtimeEnvironment: 'PowerShell-7.4'
    logProgress: true
    logVerbose: true
    description: 'Runbook to execute Maester report'
    publishContentLink: {
      uri: __ouMaesterScriptBlobUri__
    }
  }
}

@description('Schedule Deployment')
resource automationAccountSchedule 'Microsoft.Automation/automationAccounts/schedules@2024-10-23' = {
  name: 'scheduleMaester'
  parent: automationAccount
  properties: {
    advancedSchedule: {
      weekDays:[
        'Monday'
        'Wednesday'
        'Friday'
      ]
    }
    expiryTime: '9999-12-31T23:59:59.9999999+00:00'
    frequency: 'Week'
    interval: 1
    startTime: dateTimeAdd(__currentUtcTime__, 'PT1H')
    timeZone: 'W. Europe Standard Time'
  }
}

@description('Runbook Schedule Association')
resource maesterRunbookSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2024-10-23' = {
  name: guid(automationAccount.id, automationAccountRunbook.name, automationAccount.name)
  parent: automationAccount
  properties: {
    parameters: {}
    runbook: {
      name: automationAccountRunbook.name
    }
    schedule: {
      name: automationAccountSchedule.name
    }
  }
}
```

The ```app-service.bicep``` module-file automates deployment of an Azure App Service with an associated App Service Plan and configures Entra ID authentication. It ensures that the App Service can authenticate users via Entra ID and access Microsoft Graph API with the ```User.Read``` permissions.

```bicep
param __location__ string
param _appServiceName_ string
param _appServicePlanName_ string
param __ouMaesterAutomationMiId__ string
extension microsoftGraphV1

@description('Role Assignments Deployment')
resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appService
  name: guid(appService.id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role ID
    principalId: __ouMaesterAutomationMiId__
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: _appServicePlanName_
  location: __location__
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
}

resource graphMaesterApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'idp-${_appServiceName_}'
  signInAudience: 'AzureADMyOrg'
  displayName: 'idp-${_appServiceName_}'
  web: {
    redirectUris: [
      'https://${_appServiceName_}.azurewebsites.net/.auth/login/aad/callback'
    ]
    implicitGrantSettings: {
      enableIdTokenIssuance: true
      enableAccessTokenIssuance: false
    }
  }
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
      resourceAccess: [
        {
          id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
          type: 'Scope'
        }
      ]
    }
  ]
}

resource graphMaesterSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: graphMaesterApp.appId
}

resource appService 'Microsoft.Web/sites@2024-11-01' = {
  name: _appServiceName_
  location: __location__
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

resource authsettings 'Microsoft.Web/sites/config@2024-11-01' = {
 parent: appService
 name: 'authsettingsV2'
  properties: {
    globalValidation: {
      redirectToProvider: 'Microsoft'
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: graphMaesterApp.appId
          openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/v2.0'
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
        }
        validation: {
          jwtClaimChecks: {}
          allowedAudiences: [
            'api://${graphMaesterApp.appId}'
          ]
        }
      }
    }
  }
}
```

The PowerShell script has been updated to generate an HTML report, which is then zipped. This package is uploaded to the Azure Web App and published using the Managed Identity of the Automation Account, which has RBAC assignment on the Azure Web App. Save the file in the folder `pwsh` with the name `maester.ps1`
```PowerShell
#Retrieve the default automation account variables
$appName           = Get-AutomationVariable -Name 'appName'
$resourceGroupName = Get-AutomationVariable -Name 'resourceGroupName'
$TenantId          = Get-AutomationVariable -Name 'tenantId'
$Tenant            = Get-AutomationVariable -Name 'tenant'

#Retrieve the test options
$enableTeamsTests     = [System.Convert]::ToBoolean((Get-AutomationVariable -Name 'enableTeamsTests'))
$enableExchangeTests  = [System.Convert]::ToBoolean((Get-AutomationVariable -Name 'enableExchangeTests'))
$enableComplianceTests = [System.Convert]::ToBoolean((Get-AutomationVariable -Name 'enableComplianceTests'))

#Setting up the connections
Connect-MgGraph -Identity
Connect-AzAccount -Identity

if ($enableExchangeTests) {
    Connect-ExchangeOnline -ManagedIdentity -Organization $Tenant -ShowBanner:$false
}

if ($enableComplianceTests) {
    $scToken = Get-AzAccessToken -ResourceUrl "https://ps.compliance.protection.outlook.com/"
    Connect-IPPSSession -AccessToken $scToken.Token -Organization $Tenant
}

if ($enableTeamsTests) {
    Connect-MicrosoftTeams -Identity
}

#Output folder and Maester
$date = (Get-Date).ToString("yyyyMMdd-HHmm")
$FileName = "MaesterReport$($date).zip"
$TempOutputFolder = Join-Path $env:TEMP $date
if (!(Test-Path $TempOutputFolder -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $TempOutputFolder | Out-Null
}

Set-Location $env:TEMP
if (!(Test-Path ".\maester-tests")) { New-Item -ItemType Directory -Path ".\maester-tests" | Out-Null }
Set-Location ".\maester-tests"

Install-MaesterTests .\tests
Invoke-Maester -OutputHtmlFile (Join-Path $TempOutputFolder "index.html")

Compress-Archive -Path (Join-Path $TempOutputFolder "*") -DestinationPath $FileName -Force

#Deploy to Azure Web App
Connect-AzAccount -Identity
Publish-AzWebApp -ResourceGroupName $resourceGroupName -Name $appName -ArchivePath $FileName -Force
```


## Deployment

- You have the flexibility to deploy either based on deployment stacks or directly to the Azure Subscription.
- Using Deployment Stacks allows you to bundle solutions into a single package, offering several advantages
  - Management of resources across different scopes as a single unit
  - Securing resources with deny settings to prevent configuration drift
  - Easy cleanup of development environments by deleting the entire stack


Directly deployed based:
```PowerShell
#Connect to Azure
Connect-AzAccount

#Getting current context to confirm we deploy towards right Azure Subscription
Get-AzContext

# If not correct context, change, using:
# Get-AzSubscription
# Set-AzContext -SubscriptionID "ID"

#Deploy to Azure Subscription
New-AzSubscriptionDeployment -Name Maester -Location WestEurope -TemplateFile .\main.bicep -TemplateParameterFile .\main.bicepparam
```

Deployment Stack based:
```PowerShell
#Connect to Azure
Connect-AzAccount

#Getting current context to confirm we deploy towards right Azure Subscription
Get-AzContext

# If not correct context, change, using:
# Get-AzSubscription
# Set-AzContext -SubscriptionID "ID"

#Change DenySettingsMode and ActionOnUnmanage based on your needs..
New-AzSubscriptionDeploymentStack -Name Maester -Location WestEurope -DenySettingsMode None -ActionOnUnmanage DetachAll -TemplateFile .\main.bicep -TemplateParameterFile .\main.bicepparam
```
## Exchange Online and Security and Compliance access
To grant the system-assigned managed identity of the Azure Automation Account access to Exchange Online and Security & Compliance, run the PowerShell script below since this cannot be done through the portal. Update the organization variable to match your environment before running the script. This step only needs to be performed once and ensures the managed identity has the least privilege required to check your Exchange, Security and Compliance settings by assigning the View-Only Recipients role.

```PowerShell
# Managed Identity displayName
$managedIdentityDisplayName = 'aa-maester-prod-westeu-001'

# Exchange Online
$roleName = 'View-Only Recipients'
$organization = 'tenantName.onmicrosoft.com'

Connect-AzAccount -DeviceCode
$entraSp = Get-AzADServicePrincipal -Filter "displayName eq '$managedIdentityDisplayName'"
if(-not $entraSp){ throw "No servicePrincipal found with displayName $managedIdentityDisplayName" }

#===============================
# Exchange Online
#===============================
Connect-ExchangeOnline -Organization $organization

# Creates the Service Principal object in Exchange Online
New-ServicePrincipal -AppId $entraSp.AppId -ObjectId $entraSp.Id -DisplayName $entraSp.DisplayName

# Assigns the 'View-Only Configuration' role to the Managed Identity
New-ManagementRoleAssignment -Role $roleName -App $entraSp.DisplayName

#===============================
# Purview Security and Compliance
#===============================

Connect-IPPSSession -Organization $organization

# Creates the Service Principal object in Exchange Online
New-ServicePrincipal -AppId $entraSp.AppId -ObjectId $entraSp.Id -DisplayName $entraSp.DisplayName

# Assigns the 'View-Only Configuration' role to the Managed Identity
New-ManagementRoleAssignment -Role $roleName -App $entraSp.DisplayName
```

## Microsoft Teams access

To grant the system-assigned managed identity of the Azure Automation Account access to Microsoft Teams, assign the identity to the Teams Administrator role.

## Viewing the Azure Resources
We can see the resources located in the resource group called ```rg-maester-prod-westeu-001```.

![Screenshot of the Maester Azure resources](assets/azurewebapp-bicep-resources.png)

The schedule of the Automation Account which will trigger on Monday, Wednesday, and Friday to upload new Maester report to the Azure Web App. You can easily adjust the schedule to suit your needs:
![Screenshot of the Maester Azure schedule](assets/azurewebapp-bicep-schedule.png)

## Viewing the Azure Web App

![Screenshot of the Maester report email](assets/azurewebapp-test-result.png)

## FAQ / Troubleshooting

- Ensure you have the latest version of Azure Bicep, as the ```microsoftGraphV1_0``` module depends on the newer versions

## Contributors

- Original author: [Brian Veldman](https://www.linkedin.com/in/brian-veldman/) | Microsoft MVP
