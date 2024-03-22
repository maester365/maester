---
sidebar_label: Azure DevOps
sidebar_position: 2
title: Azure DevOps
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# <IIcon icon="vscode-icons:file-type-azurepipelines" height="48" /> Configure Maester in Azure DevOps

This guide will walk you through setting up Maester in Azure DevOps and automate the running of tests on your Azure DevOps pipeline.

## Set up the Maester repository in Azure DevOps

### Pre-requisites

- If this is your first time using Azure DevOps, you will first need to create an organization.
  - [Azure DevOps - Create an organization](https://learn.microsoft.com/azure/devops/organizations/accounts/create-organization)
    :::tip
    To enable the free tier of Azure Pipelines you will need to submit this form https://aka.ms/azpipelines-parallelism-request (it can take a few hours before you can use the pipeline)
    :::
- Create a new project to host your Maester tests and Azure Pipeline.
  - [Azure DevOps - Create a project](https://learn.microsoft.com/azure/devops/organizations/projects/create-project)

### Import the Maester Tests repository

- Select **Repos** from the left-hand menu
- Click the **Import** button in the **Import a repository** section
- Enter the URL of the Maester repository `https://github.com/maester365/maester-tests`
- Click **Import** to import the repository into your Azure DevOps project.

## Set up the Azure Pipeline

When authenticating with Microsoft Graph you can use one of the following methods.

- **Workload Identity Federation (WIF)** is the most secure and recommended method for Azure Pipelines since it does not require storing secrets or rotating of secrets.
  - _Note: WIF requires an Azure subscription and connections can only be made to the Entra tenant that hosts your Azure DevOps organization._
- **Certificate** stored in Azure Key Vault is an alternative method for authenticating with Microsoft Graph. Use this option if the Entra ID tenant if you are unable to use WIF.
  - _Note: An Azure subscription with a Key Vault is required to store the certificate securely._
- **Secret** is the least secure method and is not recommended.
  - Note This method does not require an Azure subscription or key vault.

<Tabs>
  <TabItem value="wif" label="Workload Identity Federation (recommended)" default>

  </TabItem>
  <TabItem value="cert" label="Certificate">

  </TabItem>
  <TabItem value="secret" label="Secret (not recommended)">

Follow the steps below to create an application identity in the Entra tenant, grant permissions to Microsoft Graph, create a secret to authenticate and set up the Azure Pipeline to use the secret.

### Create an Entra Application

- Open [Entra admin center](https://entra.microsoft.com) > **Identity** > **Applications** > **App registrations**
  - Tip: [enappreg.cmd.ms](https://enappreg.cmd.ms) is a shortcut to the App registrations page.
- Click **New registration**
- Enter a name for the application (e.g. `Maester DevOps Account`)
- Click **Register**

### Grant permissions to Microsoft Graph

- Open the application you created in the previous step
- Click **API permissions** > **Add a permission**
- Select **Microsoft Graph** > **Application permissions**
- Search for each of the permissions and check the box next to each permission:
  - **Directory.Read.All**
  - **Policy.Read.All**
- Click **Add permissions**
- Click **Grant admin consent for [your organization]**
- Click **Yes** to confirm

### Create a client secret

- Click **Certificates & secrets** > **Client secrets** > **New client secret**
- Enter a description for the secret (e.g. `Maester DevOps Secret`)
- Click **Add**
- Copy the value of the secret, we will use this value in the Azure Pipeline

### Create Azure Pipeline

- Open your Azure DevOps project
- Click **Pipelines** > **New pipeline**
- Select **Azure Repos Git** as the location of your code
- Select the repository where you imported the Maester tests
- Click **Starter pipeline**
- Click **Variable** to open the variables editor and add the following variables.
- In the Entra portal, open the application you created earlier and copy the following values from the **Overview** page:
  - Name: **TENANTID**, Value: The Directory (tenant) ID of the Entra tenant
  - Name: **CLIENTID**, Value: The Application (client) ID of the Entra application you created
  - Name: **CLIENTSECRET**, Value: The client secret you copied in the previous step
    - _Important: Tick the **Keep this value secret** checkbox_
- Replace the content of the `azure-pipelines.yml` file with the code
- Click **Validate and save** > **Save**
- Click **Run** to run the pipeline
- Click **Job** to view the test results

```yaml
# Maester Daily Tests

trigger:
  - main

pool:
  vmImage: ubuntu-latest

steps:
  - pwsh: |
      # Connect to Microsoft Graph
      $clientSecret = ConvertTo-SecureString -AsPlainText $env:PS_ClientSecret -Force
      [pscredential]$clientSecretCredential = New-Object System.Management.Automation.PSCredential($env:CLIENTID, $clientSecret)
      Connect-MgGraph -TenantId $env:TENANTID -ClientSecretCredential $clientSecretCredential

      # Install Maester
      Install-Module Maester -Force

      # Configure test results
      $PesterConfiguration = New-PesterConfiguration
      $PesterConfiguration.TestResult.Enabled = $true
      $PesterConfiguration.TestResult.OutputPath = '$(System.DefaultWorkingDirectory)/test-results/test-results.xml'

      # Run Maester tests
      Invoke-Maester -Path $(System.DefaultWorkingDirectory)/tests/Maester/ -PesterConfiguration $PesterConfiguration -OutputFolder '$(System.DefaultWorkingDirectory)/test-results'
    env:
      PS_ClientSecret: $(CLIENTSECRET)
    continueOnError: true
    displayName: Run Maester Tests
  - publish: $(System.DefaultWorkingDirectory)/test-results
    artifact: TestResults
    displayName: Publish Maester Html Report
  - task: PublishTestResults@2
    inputs:
      testResultsFormat: "NUnit"
      testResultsFiles: "**/test-results.xml"
    displayName: Publish Pester Test Results
```

  </TabItem>
  </Tabs>

## Keeping your Maester tests up to date

The Maester team will add new tests over time. To get the latest updates, use the commands below to sync your Azure repository with [maester-tests](https://github.com/maester365/maester-tests).

Run this command once in your repository to add the maester-tests repository as a remote:

```bash
git remote add public https://github.com/maester365/maester-tests
```

Run the following command to pull in updates from the maester-tests repository:

```bash
git pull public main
```
