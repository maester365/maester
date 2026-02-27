---
title: Azure DevOps tests for Maester
description: Azure DevOps Security tests for Maester
slug: azuredevops-tests-for-maester
authors: sebastian
tags: [AzureDevOps,Security]
hide_table_of_contents: false
date: 2026-02-25
# image: ./img/azure-devops-webapp-diagram.png
#draft: true # Draft
---

We are excited to announce that Azure DevOps tests are now available in Maester!

<!-- truncate -->

## Description of Azure DevOps tests

Maester now includes an *optional* suite of Azure DevOps security and resource limit tests. These are shipped alongside the core commands but are only executed when you have an
active connection to an Azure DevOps organization (using the community [ADOPS
PowerShell](https://www.powershellgallery.com/packages/ADOPS) module). Each test
is defined by a pair of files under `powershell/public/maester/azuredevops`:
a markdown document with rationale and remediation guidance, and a PowerShell
script containing the implementation.

The tests are inspired by [Learn - Azure DevOps Security Best Practices](https://learn.microsoft.com/en-us/azure/devops/organizations/security/security-overview?view=azure-devops) and include a subset of the available configurations and settings.

To run the entire set, you can simply connect and run Invoke-Maester:

```pwsh
Install-Module ADOPS
Connect-ADOPS -Organization <name>
Invoke-Maester
```

> Certain cmdlets will use unsupported REST API endpoints in Azure DevOps and may result in error(s) when Azure DevOps endpoints are changed without notice, hence the -Force flag running for certain tests.

### Permissions
- At least a basic license in Azure DevOps
- Certain tests require either organization-level permissions such as "Project Collection Administrator" or tenant-level permissions such as "Azure DevOps Administrator".

> [Manage policies as Administrator - Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)

### Available tests

| Test ID | Severity | Description | Link |
|---------|----------|-------------|------|
| AZDO.1000 | High | Third-party application access via OAuth should be disabled. | [Learn more](https://aka.ms/vstspolicyoauth) |
| AZDO.1001 | High | Connecting to Azure DevOps using SSH should be disabled. | [Learn more](https://aka.ms/vstspolicyssh) |
| AZDO.1002 | High | Auditing should be enabled. | [Learn more](https://aka.ms/log-audit-events) |
| AZDO.1003 | High | External guest access to Azure DevOps should be a controlled process. | [Learn more](https://aka.ms/vsts-anon-access) |
| AZDO.1004 | High | Externally sourced package versions should be manually approved for internal use to prevent malicious packages. | [Learn more](https://aka.ms/upstreamBehaviorBlog) |
| AZDO.1005 | High | Conditional Access Policies should be configured for Microsoft Entra ID-backed organizations. | [Learn more](https://aka.ms/visual-studio-conditional-access-policy) |
| AZDO.1006 | High | External users access should be a controlled process. | [Learn more](https://aka.ms/vstspolicyguest) |
| AZDO.1007 | High | Team and project administrators should not be allowed to invite new users. | [Learn more](https://aka.ms/azure-devops-invitations-policy) |
| AZDO.1008 | High | Request access to Azure DevOps by email notifications to administrators should be disabled. | [Learn more](https://go.microsoft.com/fwlink/?linkid=2113172) |
| AZDO.1009 | Info | Providing or collecting customer feedback to the product team for Azure DevOps should be enabled. | [Learn more](https://aka.ms/ADOPrivacyPolicy) |
| AZDO.1010 | High | Audit logs should be retained according to your organization's needs and protected from purging. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/audit/auditing-streaming?view=azure-devops) |
| AZDO.1011 | Info | Azure DevOps supports up to 1,000 projects within an organization. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/projects/about-projects?view=azure-devops) |
| AZDO.1012 | Info | Azure DevOps supports up to 150,000 tag definitions per organization or collection. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/settings/work/object-limits?view=azure-devops) |
| AZDO.1013 | High | Azure DevOps organization owner should not be assigned to a regular user. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-organization-ownership?view=azure-devops) |
| AZDO.1014 | High | Status badges in Azure DevOps should be disabled for anonymous access. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/create-first-pipeline?view=azure-devops&tabs=net%2Cbrowser#add-a-status-badge-to-your-repository) |
| AZDO.1015 | High | User-defined variables should not be able to override system variables or variables not defined by the pipeline author. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#limit-variables-that-can-be-set-at-queue-time) |
| AZDO.1016 | High | YAML & build pipelines should have restricted access to only those repositories in the same project as the pipeline. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope) |
| AZDO.1017 | High | Release pipelines should have restricted access to only those repositories in the same project as the pipeline. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope) |
| AZDO.1018 | High | Access to repositories in YAML pipelines should apply checks and approval before granting access. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#restrict-project-repository-and-service-connection-access) |
| AZDO.1019 | High | Users should not be able to select stages to skip from the Queue Pipeline panel. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops) |
| AZDO.1020 | High | Creating classic build pipelines should be disabled. | [Learn more](https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/) |
| AZDO.1021 | High | Creating classic release pipelines should be disabled. | [Learn more](https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/) |
| AZDO.1022 | High | Azure DevOps pipelines should validate contributions from forked GitHub repositories before running. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops&tabs=yaml#validate-contributions-from-forks) |
| AZDO.1023 | High | Disable the ability to install and run tasks from the Marketplace to maintain control. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#prevent-malicious-code-execution) |
| AZDO.1024 | High | Disable Node 6 tasks to avoid deprecated runtime environments. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2022/no-node-6-on-hosted-agents) |
| AZDO.1025 | High | Enable shell task validation to prevent code injection. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#shellTasksValidation) |
| AZDO.1026 | Medium | GitHub Advanced Security for Azure DevOps should be automatically enabled for new projects. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml#organization-level-onboarding) |
| AZDO.1027 | Medium | Gravatar images should not be exposed for users outside your enterprise. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/repos/git/repository-settings?view=azure-devops&tabs=browser#gravatar-images) |
| AZDO.1028 | High | Creation of Team Foundation Version Control (TFVC) repositories should be disabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2024/no-tfvc-in-new-projects) |
| AZDO.1029 | Medium | Azure Artifacts storage limit should not be met. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/artifacts/reference/limits?view=azure-devops) |
| AZDO.1030 | Critical | Project Collection Administrator membership should be restricted to the minimum number of accounts required and regularly reviewed. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/security/about-permissions?view=azure-devops&tabs=preview-page#permissions) |
| AZDO.1031 | High | Validation of SSH key expiration date should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#validate-ssh-key-expiration) |
| AZDO.1032 | High | Restriction of global Personal Access Token creation should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-creation-of-global-pats-tenant-policy) |
| AZDO.1033 | High | Automatic revocation of leaked Personal Access Tokens should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#automatic-revocation-of-leaked-tokens) |
| AZDO.1034 | High | Restrict creation of new Azure DevOps organizations. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/organization-management?view=azure-devops) |
| AZDO.1035 | High | Restriction of Personal Access Token lifespan should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-personal-access-token-lifespan) |
| AZDO.1036 | High | Restriction of full-scoped Personal Access Token creation should be enabled. | [Learn more](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-full-scope-personal-access-tokens) |


### Quick Stats

- 🚀 Automated security tests for Azure DevOps using Maester
- 🔢 37 tests in total
- 🔴 1 Critical | 🟠 30 High | 🟡 3 Medium | 🔵 3 Info

### Get Started

Follow the step-by-step guide to set up Maester in Azure DevOps with required resources:

- Documentation: [Azure DevOps tests](/docs/monitoring/azure-devops-tests)

## Contributor

- [Sebastian Claesson](/blog/authors/sebastian)
