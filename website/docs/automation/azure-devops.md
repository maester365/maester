---
sidebar_label: Azure DevOps
sidebar_position: 2
title: Azure DevOps
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import GraphPermissions from '../sections/permissions.md';

# <IIcon icon="vscode-icons:file-type-azurepipelines" height="48" /> Configure Maester in Azure DevOps

This guide will walk you through setting up Maester in Azure DevOps and automate the running of tests using Azure DevOps Pipelines.

## Why Azure DevOps?

Azure DevOps is a great way to automate the daily running of Maester tests. You can use Azure DevOps to run Maester tests on a schedule, such as daily, and view the results in the Azure DevOps interface.

Azure DevOps comes with a [free tier](https://azure.microsoft.com/pricing/details/devops/azure-devops-services/) that includes 1,800 minutes of Maester test runs per month (unlimited hours if you use a self-hosted agent).

Azure DevOps has native integration with Microsoft Entra including single sign on, user and group management as well as support for conditional access policies.

## Set up the Maester repository in Azure DevOps

### Pre-requisites

- If this is your first time using Azure DevOps, you will first need to create an organization.
  - [Azure DevOps - Create an organization](https://learn.microsoft.com/azure/devops/organizations/accounts/create-organization)
    :::tip
    To enable the free tier, to use a Microsoft-hosted agent, for Azure Pipelines you will need to submit this form https://aka.ms/azpipelines-parallelism-request (it can take a few days before you can use the pipeline.) In the interim you can use a [self-hosted agent](https://learn.microsoft.com/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=yaml%2Cbrowser#self-hosted-agents) to get started.
    :::
- Create a new project to host your Maester tests and Azure Pipeline.
  - [Azure DevOps - Create a project](https://learn.microsoft.com/azure/devops/organizations/projects/create-project)

### Import the Maester Tests repository

- Select **Repos** from the left-hand menu
- Click the **Import** button in the **Import a repository** section
- Enter the URL of the Maester repository `https://github.com/maester365/maester-tests`
- Click **Import** to import the repository into your Azure DevOps project.

## Set up the Azure Pipeline

There are many ways to authenticate with Microsoft Entra in Azure DevOps. We recommend using [**workload identity federation**](https://learn.microsoft.com/entra/workload-id/workload-identity-federation) as it is more secure, requires less maintenance and is the easiest to set up.

If you’re unable to use more advanced options like certificates stored in Azure Key Vault, which need an Azure subscription, there’s also guidance available for using client secrets.

- <IIcon icon="gravity-ui:nut-hex" height="18" /> **Workload identity federation** (recommended) uses OpenID Connect (OIDC) to authenticate with Microsoft Entra protected resources without using secrets.
- <IIcon icon="material-symbols:password" height="18" /> **Client secret** uses a secret to authenticate with Microsoft Entra protected resources.

<Tabs>
  <TabItem value="wif" label="Workload identity federation (recommended)" default>

### Create an empty Azure Resource Group

This empty resource group is required to set up workload identity federation authentication. No Azure resources will be created in this resource group and there are no costs associated with it.

- Open the [Azure portal](https://portal.azure.com)
- Click **Create a resource** > **Resource group**
- Enter a name for the resource group (e.g. `Maester Resource Group`)
- Select any region
- Click **Review + create** > **Create**

### Create a new workload identity federation service connection

- In the Azure DevOps project, go to **Project settings** > **Service connections**.
- Select **New service connection**, and then select **Azure Resource Manager**.
- Select **Workload identity federation (automatic)**.
- Specify the following parameters:
  - **Subscription**: Select an existing Azure subscription.
  - **Resource Group**: Select the resource group created in the previous step. (e.g. `Maester Resource Group`) Leaving this field empty will grant Contribute access to all resources in the subscription.
  - **Service connection name**: A name for this connection (e.g. `Maester Service Connection`)
- Click **Save** to create the connection.

### Grant permissions to Microsoft Graph

- Select the service connection you created in the previous step (e.g. `Maester Service Connection`)
  - Service connections are listed under **Project settings** > **Service connections**.
- Select **Manage Service Principal** to open the Service Principal in the Entra portal.
- Click **API permissions** > **Add a permission**
- Select **Microsoft Graph** > **Application permissions**
- Search for each of the permissions and check the box next to each permission:
  <GraphPermissions/>
- Click **Add permissions**
- Click **Grant admin consent for [your organization]**
- Click **Yes** to confirm

### Create Azure Pipeline

- Open your Azure DevOps project
- Click **Pipelines** > **New pipeline**
- Select **Azure Repos Git** as the location of your code
- Select the repository where you imported the Maester tests
- Click **Starter pipeline**
- Replace the content of the `azure-pipelines.yml` file with the code below
- Verify the `azureSubscription` value is set to the service connection you created in the previous step (e.g. `Maester Service Connection`)
- Click **Validate and save** > **Save**
- Click **Run** to run the pipeline
- Click **Job** to view the test results

```yaml
# Maester Daily Tests

trigger:
  - main

schedules:
  - cron: "0 0 * * *"
    displayName: Daily midnight build
    branches:
      include:
        - main

pool:
  vmImage: ubuntu-latest

steps:
  - task: AzurePowerShell@5
    displayName: "Run Maester"
    inputs:
      azureSubscription: "Maester Service Connection"
      pwsh: true
      azurePowerShellVersion: LatestVersion
      ScriptType: InlineScript
      Inline: |
        # Connect to Microsoft Graph
        $accessToken = (Get-AzAccessToken -ResourceTypeName MSGraph).Token | ConvertTo-SecureString -AsPlainText -Force
        Connect-MgGraph $accessToken

        # Install Maester
        Install-Module Maester -Force

        # Configure test results
        $PesterConfiguration = New-PesterConfiguration
        $PesterConfiguration.TestResult.Enabled = $true
        $PesterConfiguration.TestResult.OutputPath = '$(System.DefaultWorkingDirectory)/test-results/test-results.xml'

        # Run Maester tests
        Invoke-Maester -Path $(System.DefaultWorkingDirectory)/tests/Maester/ -PesterConfiguration $PesterConfiguration -OutputFolder '$(System.DefaultWorkingDirectory)/test-results'
  - publish: $(System.DefaultWorkingDirectory)/test-results
    displayName: Publish Maester Html Report
    artifact: TestResults
  - task: PublishTestResults@2
    displayName: Publish Pester Test Results
    inputs:
      testResultsFormat: "NUnit"
      testResultsFiles: "**/test-results.xml"
      failTaskOnFailedTests: true
```

  </TabItem>
  <TabItem value="cert" label="Client secret">

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
  <GraphPermissions/>
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
- Replace the content of the `azure-pipelines.yml` file with the code below
- Click **Validate and save** > **Save**
- Click **Run** to run the pipeline
- Click **Job** to view the test results

```yaml
# Maester Daily Tests

trigger:
  - main

schedules:
  - cron: "0 0 * * *"
    displayName: Daily midnight build
    branches:
      include:
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

## Viewing test results

- Click **Pipelines** > **Runs** to view the status of the pipeline
- Click on a run to view the test results

### Summary view

The summary view shows the status of the pipeline run, the duration, and the number of tests that passed, failed, and were skipped.

![Screenshot of Azure DevOps Pipeline Run Summary Page](assets/azure-devops-summary-page.png)

### Maester report

The Maester report can be downloaded and viewed by selecting the **Published** artifact.

![Screenshot of Azure DevOps Pipeline Run Summary Page](assets/azure-devops-maester-report.png)

### Tests view

The **Tests** tab shows a detailed view of each test, including the test name, duration, and status.

## ![Screenshot of Azure DevOps Pipeline Run Summary Page](assets/azure-devops-tests-page.png)

### Logs view

In the **Summary** tab click on any of the errors to view the raw logs from Maester.

## ![Screenshot of Azure DevOps Pipeline Run Summary Page](assets/azure-devops-logs-page.png)

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
