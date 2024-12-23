---
sidebar_label: Azure Container App Job
sidebar_position: 7
title: Set up Maester in Azure Container App Job
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import GraphPermissions from '../sections/permissions.md';
import CreateEntraApp from '../sections/create-entra-app.md';
import CreateEntraClientSecret from '../sections/create-entra-client-secret.md';
import EnableGitHubActionsCreateWorkflow from '../sections/enable-github-actions-workflow.md';

# <IIcon icon="devicon:azure" height="48" /> Setup Maester in Azure Container App Jobs

This guide will summarize the major requirements in setting up Maester in Azure Container App Jobs. You may find gaps in this guide or areas requiring clarification. Please [open a discussion](https://github.com/maester365/maester/discussions/new/choose) if you run into challenges this guide does not address.

## Why Azure Container App Jobs

Azure Container App Jobs allow you to run custom container images and run those images on demand as needed. Although more complex than alternative methods offered, there is additional flexibility with having a base image to customize.

### Pre-requisites

- If this is your first time using Microsoft Azure, you must set up an [Azure Subscription](https://learn.microsoft.com/azure/cost-management-billing/manage/create-subscription) so you can create resources and are billed appropriately
- You must also have the **Global Administrator** role in your Entra tenant. This is so the necessary permissions can be consented
- An instance where you have [Docker installed](https://github.com/docker/docker-install?tab=readme-ov-file#dockerdocker-install)
- A Docker [image with PowerShell Core](https://learn.microsoft.com/en-us/powershell/scripting/install/powershell-in-docker#using-powershell-in-a-container) installed
- An Azure Container Registry for hosting your image
- Optionally:
  - Azure VM with a Managed Identity as your build instance (Assign Application Administrator Entra Role)
  - Azure Key Vault for storing secret material
  - Azure Storage Account for storing test results

## Create your Entra Application

<CreateEntraApp/>

### Configure Certificate Based Authentication for your Service Principal

The following PowerShell script will enable you to:
- Identify the Service Principal Application (Client) ID and Display Name and an existing Azure Key Vault Name
- Install the necessary modules and prompt for authentication to Azure and Graph
 - If you are using a system with a managed identity for your build environment you can use the `-Identity` switch for the connection commands.
- Define a certificate policy and request Key Vault to create the certifcate
 - ⚠️ This policy creates a certificate that **will expire** after 12 months, ensure you update it appropriately
- Wait until the certificate becomes available in the Key Vault
- Retrieve the public key from the Key Vault
- Set the public key as an authentication method for the Entra Application Registration

Alternatively, if you prefer not to use a Key Vault, [Microsoft provides guidance](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-self-signed-certificate) to perform similar steps.

```powershell
$applicationId = "<Application (Client) ID>"
$applicationDisplayName = "<Application Display Name"
$keyVaultName = "<Key Vault Name>"

Install-Module Az.Accounts -Force
Install-Module Az.KeyVault -Force
Connect-AzAccount
Install-Module Microsoft.Graph.Authentication -Force
Connect-MgGraph

$Policy = New-AzKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName "CN=$applicationDisplayName" -IssuerName "Self" -ValidityInMonths 12 -ReuseKeyOnRenewal
Add-AzKeyVaultCertificate -VaultName $keyVaultName -Name $applicationDisplayName -CertificatePolicy $Policy

$status = $false
while($status){
  if((Get-AzKeyVaultCertificateOperation -VaultName $keyVaultName -Name $applicationDisplayName).Status -eq "completed"){
    $status = $true
  }else{
    "Cert not issued, waiting";Start-Sleep -Seconds 5
  }
}
$kvCert = Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $applicationDisplayName

$body = @{
  keyCredentials = @(
    @{
      endDateTime = $kvCert.Certificate.notAfter
      startDateTime = $kvCert.Certificate.notBefore
      type = "AsymmetricX509Cert"
      usage = "Verify"
      key = $([Convert]::ToBase64String($kvCert.Certificate.RawData))
      displayName = $kvCert.Certificate.subject
    }
  )
} | ConvertTo-Json
Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications(appId='$applicationId')" -Body $body
```

## Create your Docker image

Using Docker you can define process steps and save those steps as layers to an image. When you build an image it is possible for secret material to exist in the image's layers. To avoid this there are two components you will use below. The first is a PowerShell script, `main.ps1`, that you will instruct the Docker image to execute each time the image is run. The second is a simple Dockerfile that provides all the prerequisities for the PowerShell script.

The following PowerShell script will enable you to:
- Define the key aspects of your environment
- Update any Maester tests each time the container is run
- Connect to the environment as the container's managed identity
- Obtain the private key of your Serivce Principal to authenticate against Entra with
- Connect to the environment as the Service Principal
- Run Maester
- Sync the results with an Azure Storage Account
  - Alternatively you can utilize a Git repo
  - The below example uses Storage Account connection strings that the system assigned managed identity retrieves, alternatively you can use a user assigned managed identity to avoid connection strings
- Compare the test results for the last two tests

```powershell
### main.ps1
$applicationId = "<Application (Client) ID>"
$tenantId = "<Tenant ID you want to run Maester against>"
$applicationDisplayName = "<Application Display Name"
$keyVaultName = "<Key Vault Name>"
$storageAccountName = "<Storage Account Name>"
$storageAccountResourceGroupName = "<Name of Resource Group Storage Account exists>"
Update-MaesterTests
#Connect to serivce provider tenant
Connect-MgGraph -Identity -NoWelcome
Connect-AzAccount -Identity
#Get SPN credential
$b64 = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $applicationDisplayName -AsPlainText
$bytes = [Convert]::FromBase64String($b64)
Set-Content -Path /cert.pfx -value $bytes -AsByteStream
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
#Connect to target tenant
Connect-MgGraph -AppId $applicationId -Certificate $cert -TenantId $tenantId -NoWelcome
$domains = Invoke-MgGraphRequest -Uri https://graph.microsoft.com/v1.0/domains
$moera = ($domains.value|?{$_.isInitial}).id
#Cmdlet load kills docker image at 1GB memory node
Connect-ExchangeOnline -Certificate $cert -AppID $applicationId -Organization $moera -ShowBanner:$false
Connect-IPPSSession -Certificate $cert -AppID $applicationId -Organization $moera -ShowBanner:$false
Connect-AzAccount -ServicePrincipal -ApplicationId $applicationId -TenantId $tenantId -CertificatePath /cert.pfx
#Run Maester
Invoke-Maester -SkipGraphConnect -NonInteractive
#Reconnect to service provider tenant
Connect-AzAccount -Identity
#Sync results with storage account
$stAccount = Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $storageAccountResourceGroupName
$stContainer = Get-AzStorageContainer -Context $stAccount.Context -Name $tenantId
if(-not $stContainer){$stContainer = New-AzStorageContainer -Context $stAccount.Context -Name $tenantId}
gci ./test-results/|%{Set-AzStorageBlobContent -Container $stContainer.Name -Context $stAccount.Context -File $_ -Blob $_.Name -Force|Out-Null}
$jsonResults = Get-AzStorageBlob -Container $stContainer.Name -Context $stAccount.Context -Blob "TestResults*.json"
#$jsonResults.Name.Substring(12,17)|%{[DateTime]::ParseExact($_,"yyyy-MM-dd-HHmmss",$null)}
$compare = ($jsonResults|Sort-Object $_.LastModified.DateTime -Descending)[-2]
Get-AzStorageBlobContent -Container $stContainer.Name -Context $stAccount.Context -Blob $compare.Name -Destination /maester/test-results/|Out-Null
$comparison = Compare-MtTestResult -BaseDir /maester/test-results
$comparisonFile = New-Item -Path /maester/ -Name "compare-$($compare.Name)" -Value $($comparison|ConvertTo-Json)
Set-AzStorageBlobContent -Container $stContainer.Name -Context $stAccount.Context -File $comparisonFile -Blob $comparisonFile.Name -Force|Out-Null
```

The following Dockerfile will enable you to prepare the image to successfully run the `main.ps1` file.

```dockerfile
FROM mcr.microsoft.com/powershell
SHELL ["pwsh","-Command"]
COPY main.ps1 /
RUN New-Item /maester -ItemType Directory
WORKDIR "/maester"
RUN Install-Module Az.Accounts -Force
RUN Install-Module Az.KeyVault -Force
RUN Install-Module Az.Storage -Force
RUN Install-Module Microsoft.Graph.Authentication -Force
RUN Install-Module ExchangeOnlineManagement -Force
RUN Install-Module Maester -Force

CMD & /main.ps1
```

### Push your image to ACR

With your Azure Container Registry setup and authorizing your build instance managed identity for pushing, you can use the following process to properly tag and push your image.

> The `docker build` example assumes you place both the `main.ps1` and `Dockerfile` files in the current working directory.

```bash
sudo docker build -t maesterjob .
sudo docker tag maesterjob <yourRegistry>.azurecr.io/maesterjob
sudo pwsh -command "Connect-AzAccount -Identity"
sudo pwsh -command "Connect-AzContainerRegistry -Name <yourRegistry>"
sudo docker push <yourRegistry>.azurecr.io/maesterjob
```

## Create your Azure Container App Job

Begin by [creating a new Azure Container App Job](https://portal.azure.com/#create/Microsoft.ContainerAppJobs). You can use a simple cron job, an event trigger, or you can always manually invoke the job as well. Your Azure Container Registry will need to have an admin access key enabled for the Azure Portal process to succeed.

> For the CPU and memory, you may find that 1 GB of memory is not enough and 1.5 GB or 2 GB will offer more consistent success.
