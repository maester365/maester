---
sidebar_label: Azure DevOps
sidebar_position: 2
title: Azure DevOps
---

# <IIcon icon="vscode-icons:file-type-azurepipelines" height="48" /> Configure Maester in Azure DevOps

This guide will walk you through setting up Maester in Azure DevOps and automate the running of tests on your Azure DevOps pipeline.

## Set up the Maester repository in Azure DevOps

### Pre-requisites

- If this is your first time using Azure DevOps, you will first need to create an organization.
  - [Azure DevOps - Create an organization](https://learn.microsoft.com/azure/devops/organizations/accounts/create-organization)
    :::tip
  - To enable the free tier of Azure Pipelines you will need to submit this form https://aka.ms/azpipelines-parallelism-request (it can take a few hours before you can use the pipeline)
    :::
- Create a new project to host your Maester tests and Azure Pipeline.
  - [Azure DevOps - Create a project](https://learn.microsoft.com/azure/devops/organizations/projects/create-project)

### Import the Maester Tests repository

- Select **Repos** from the left-hand menu
- Click the **Import** button in the **Import a repository** section
- Enter the URL of the Maester repository `https://github.com/maester365/maester-tests`
- Click **Import** to import the repository into your Azure DevOps project.

## Set up the Azure Pipeline

```
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
    testResultsFormat: 'NUnit'
    testResultsFiles: '**/test-results.xml'
    failTaskOnFailedTests: true
  displayName: Publish Pester Test Results
```

## Pull updates from Maester

The Maester team will add new tests over time.

To get the latest updates, use the commands below to sync your repository with [maester-tests](https://github.com/maester365/maester-tests).

Run this command once in your repository to add the maester-tests repository as a remote:

```bash
git remote add public https://github.com/maester365/maester-tests
```

Run the following command to pull in updates from the maester-tests repository:

```bash
git pull public main
```
