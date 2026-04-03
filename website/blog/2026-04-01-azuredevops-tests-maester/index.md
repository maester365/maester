---
title: Azure DevOps tests for Maester
description: Azure DevOps Security tests for Maester
slug: azuredevops-tests-for-maester
authors: sebastian
tags: [AzureDevOps,Security]
hide_table_of_contents: false
date: 2026-04-01
# image: ./img/azure-devops-webapp-diagram.png
#draft: true # Draft
---

Azure DevOps tests are now available in Maester!

<!-- truncate -->

## Overview

Maester now includes an *optional* suite of Azure DevOps security and resource limit tests. The tests are bundled with Maester and are automatically discovered when you run `Invoke-Maester`. However, they are only executed if you have an active connection to an Azure DevOps organization using the community [ADOPS PowerShell](https://www.powershellgallery.com/packages/ADOPS) module. Without a connection, the tests are skipped.

Each test includes a markdown document with rationale and remediation guidance, and a PowerShell script containing the implementation. The tests are inspired by [Learn - Azure DevOps Security Best Practices](https://learn.microsoft.com/en-us/azure/devops/organizations/security/security-overview?view=azure-devops) and cover a subset of the available settings.

To get started:

```powershell
Install-Module Maester, ADOPS
Connect-ADOPS -Organization <your-organization>
Invoke-Maester
```

That's it — Maester detects the Azure DevOps connection and runs the tests automatically alongside any other configured tests.

> Some tests use unsupported Azure DevOps REST API endpoints that may change without notice. These tests use the `-Force` flag internally to bypass the unsupported API warning.

### Permissions

- At least a **Basic** access level license in Azure DevOps
- Certain tests require organization-level permissions such as "Project Collection Administrator" (e.g., AZDO.1030) or tenant-level permissions such as "Azure DevOps Administrator" (e.g., AZDO.1032-1036).

> [Manage policies as Administrator - Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)

### Available tests

| Test ID | Severity | Description | Link |
| --------- | ---------- | ------------- | ------ |
| AZDO.1000 | High | Third-party application access via OAuth should be disabled. | [Learn more](https://aka.ms/vstspolicyoauth) |
| AZDO.1001 | High | Connecting to Azure DevOps using SSH should be disabled. | [Learn more](https://aka.ms/vstspolicyssh) |
| AZDO.1002 | High | Auditing should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/audit/azure-devops-auditing?view=azure-devops&tabs=preview-page#enable-and-disable-auditing) |
| AZDO.1003 | High | Public projects should be disabled. | [Learn more](https://aka.ms/vsts-anon-access) |
| AZDO.1004 | High | Externally sourced package versions should be manually approved for internal use to prevent malicious packages from a public registry being inadvertently consumed. | [Learn more](https://devblogs.microsoft.com/devops/changes-to-azure-artifact-upstream-behavior/) |
| AZDO.1005 | High | Conditional Access Policies should be configured for Microsoft Entra ID-backed organizations. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#cap-support-on-azure-devops) |
| AZDO.1006 | High | External guest access to Azure DevOps should be a controlled process. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/security/security-overview?view=azure-devops#manage-external-guest-access) |
| AZDO.1007 | High | Access to Azure DevOps should be a controlled process managed by the IAM team or the appropriate Azure DevOps administrator roles. | [Learn more](https://aka.ms/azure-devops-invitations-policy) |
| AZDO.1008 | Medium | Request access to Azure DevOps by email notifications to administrators should be disabled. | [Learn more](https://go.microsoft.com/fwlink/?linkid=2113172) |
| AZDO.1009 | Info | Providing or collecting customer feedback to the product team for Azure DevOps should be enabled. | [Learn more](https://aka.ms/ADOPrivacyPolicy) |
| AZDO.1010 | High | Audit logs should be retained according to your organization's needs and protected from purging. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/audit/auditing-streaming?view=azure-devops) |
| AZDO.1011 | Info | Azure DevOps supports up to 1,000 projects within an organization. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/projects/about-projects?view=azure-devops) |
| AZDO.1012 | Info | Azure DevOps supports up to 150,000 tag definitions per organization or collection. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/settings/work/object-limits?view=azure-devops) |
| AZDO.1013 | High | Azure DevOps organization owner should not be assigned to a regular user. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-organization-ownership?view=azure-devops) |
| AZDO.1014 | Medium | Status badges in Azure DevOps should be disabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/create-first-pipeline?view=azure-devops&tabs=net%2Cbrowser#add-a-status-badge-to-your-repository) |
| AZDO.1015 | High | User-defined variables should not be able to override system variables or variables not defined by the pipeline author. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#limit-variables-that-can-be-set-at-queue-time) |
| AZDO.1016 | High | YAML & build pipelines should have restricted access to only those repositories in the same project as the pipeline. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope) |
| AZDO.1017 | High | Release pipelines should have restricted access to only those repositories in the same project as the pipeline. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope) |
| AZDO.1018 | High | Access to repositories in YAML pipelines should apply checks and approval before granting access. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#restrict-project-repository-and-service-connection-access) |
| AZDO.1019 | Medium | Users should not be able to skip stages defined by the pipeline author. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops) |
| AZDO.1020 | Medium | Creating classic build pipelines should be disabled. | [Learn more](https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/) |
| AZDO.1021 | Medium | Creating classic release pipelines should be disabled. | [Learn more](https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/) |
| AZDO.1022 | High | Azure DevOps pipelines should not automatically build on every pull request and commit from a GitHub repository. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops&tabs=yaml#validate-contributions-from-forks) |
| AZDO.1023 | High | Disable the ability to install and run tasks from the Marketplace, which gives you greater control over the code that executes in a pipeline. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#prevent-malicious-code-execution) |
| AZDO.1024 | Medium | Disable Node 6 tasks. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2022/no-node-6-on-hosted-agents) |
| AZDO.1025 | High | Enable Shell Task Validation to prevent code injection. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#shellTasksValidation) |
| AZDO.1026 | Medium | GitHub Advanced Security for Azure DevOps should be automatically enabled for new projects. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml#organization-level-onboarding) |
| AZDO.1027 | Medium | Gravatar images should not be exposed for users outside your enterprise. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/repos/git/repository-settings?view=azure-devops&tabs=browser#gravatar-images) |
| AZDO.1028 | Medium | Creation of Team Foundation Version Control (TFVC) repositories should be disabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2024/no-tfvc-in-new-projects) |
| AZDO.1029 | Medium | Azure Artifacts storage limit should not be reached. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/artifacts/reference/limits?view=azure-devops) |
| AZDO.1030 | Critical | Project Collection Administrator is a highly privileged role, and membership should be restricted and regularly reviewed. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/security/about-permissions?view=azure-devops&tabs=preview-page#permissions) |
| AZDO.1031 | High | Validation of SSH key expiration date should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#ssh-key-policies) |
| AZDO.1032 | High | Restrict creation of global Personal Access Tokens (PATs) should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-creation-of-global-pats-tenant-policy) |
| AZDO.1033 | Critical | Automatic revocation of leaked Personal Access Tokens should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#automatic-revocation-of-leaked-tokens) |
| AZDO.1034 | High | Restrict creation of new Azure DevOps organizations should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/azure-ad-tenant-policy-restrict-org-creation?view=azure-devops#turn-on-the-policy) |
| AZDO.1035 | High | Restrict setting a maximum Personal Access Token (PAT) lifespan should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-personal-access-token-lifespan) |
| AZDO.1036 | High | Restrict creation of full-scoped Personal Access Tokens (PATs) should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-creation-of-full-scoped-pats-tenant-policy) |

### Quick Stats

- 🔢 37 tests in total
- 🔴 2 Critical | 🟠 22 High | 🟡 10 Medium | 🔵 3 Info

### Azure DevOps Pipeline Example

For automated monitoring, the following pipeline runs Maester tests (including the Azure DevOps tests) on a schedule and publishes the results to an Azure Web App. The pipeline connects to both Microsoft Graph (for Entra ID tests) and Azure DevOps.

**Prerequisites:**
- An **app registration** with the required [Maester permissions](https://maester.dev/docs/installation#configure-permissions)
- A **workload identity federation service connection** in Azure DevOps
- An **Azure Web App** to host the report (see [Maester results on Azure Web App](/blog/maester-with-azdo-webapp))

Update the following variables in the pipeline to match your environment:

| Variable | Description | Where to find it |
| --- | --- | --- |
| `ServiceConnection` | Name of your Azure DevOps service connection (workload identity federation) | Azure DevOps > Project Settings > Service connections |
| `WebAppSubscriptionId` | Azure subscription ID where the Web App is hosted | Azure Portal > Subscriptions |
| `WebAppResourceGroup` | Resource group containing the Web App | Azure Portal > Resource groups |
| `WebAppName` | Name of the Azure Web App for the report | Azure Portal > App Services |
| `TenantId` | Your Microsoft Entra tenant ID | Azure Portal > Microsoft Entra ID > Overview |
| `ClientId` | Application (client) ID of the app registration | Azure Portal > App registrations > Overview |
| `DevOpsOrganization` | Your Azure DevOps organization name (as it appears in `dev.azure.com/<name>`) | Azure DevOps > Organization Settings |

```yaml
trigger: none

variables:
  ServiceConnection: <your-service-connection>
  WebAppSubscriptionId: <your-subscription-id>
  WebAppResourceGroup: <your-resource-group>
  WebAppName: <your-web-app-name>
  TenantId: <your-tenant-id>
  ClientId: <your-client-id>
  DevOpsOrganization: <your-devops-organization>

schedules:
- cron: "0 6 * * *"
  displayName: Daily at 06:00
  always: true
  branches:
    include:
    - main

jobs:
- job: maester
  pool:
    vmImage: ubuntu-latest

  steps:
  - checkout: self
    fetchDepth: 1

  - task: AzurePowerShell@5
    inputs:
      azureSubscription: '$(ServiceConnection)'
      ScriptType: 'InlineScript'
      pwsh: true
      azurePowerShellVersion: latestVersion
      Inline: |
        # Install modules
        Install-Module 'Maester', 'Pester', 'Microsoft.Graph.Authentication', 'ADOPS' -SkipPublisherCheck -Confirm:$false -Force

        # Connect to Microsoft Graph
        $graphToken = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com' -AsSecureString
        Connect-MgGraph -AccessToken $graphToken.Token -NoWelcome

        # Connect to Azure DevOps
        $DevOpsToken = ConvertFrom-SecureString -SecureString (Get-AzAccessToken -AsSecureString -TenantId '$(TenantId)').Token -AsPlainText
        Connect-ADOPS -Organization '$(DevOpsOrganization)' -OAuthToken $DevOpsToken

        # Prepare output folder
        $date = (Get-Date).ToString("yyyyMMdd-HHmm")
        $TempOutputFolder = "$PWD/temp$date"
        New-Item -ItemType Directory -Force -Path $TempOutputFolder
        New-Item -ItemType File -Force -Path "$TempOutputFolder/index.html"

        # Install and run Maester tests
        mkdir maester-tests
        cd maester-tests
        Install-MaesterTests .\tests
        Invoke-Maester -OutputHtmlFile "$TempOutputFolder/index.html" -Verbosity Normal

        # Publish to Azure Web App
        $FileName = "$PWD/MaesterReport$date.zip"
        Compress-Archive -Path "$TempOutputFolder/*" -DestinationPath $FileName
        Select-AzSubscription -Subscription '$(WebAppSubscriptionId)'
        Publish-AzWebApp -ResourceGroupName '$(WebAppResourceGroup)' -Name '$(WebAppName)' -ArchivePath $FileName -Force
    displayName: 'Run Maester tests and publish report'
```

> This pipeline only includes Microsoft Graph and Azure DevOps connections. To add Exchange Online, Teams, or Security & Compliance, see the [advanced connection guide](/docs/connect-maester/connect-maester-advanced).

### Documentation

- [Setting up Maester in Azure DevOps Pipelines](/docs/monitoring/azure-devops)
- [Maester results on Azure Web App](/blog/maester-with-azdo-webapp)
- [Deploy Maester Web App with Bicep](/docs/monitoring/azure-devops-web-app-bicep)

## Contributor

- [Sebastian Claesson](/blog/authors/sebastian)
