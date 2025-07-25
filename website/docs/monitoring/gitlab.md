---
sidebar_label: GitLab
sidebar_position: 5
title: Set up Maester in GitLab
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import GraphPermissions from '../sections/permissions.md';
import CreateEntraApp from '../sections/create-entra-app.md';
import CreateEntraClientSecret from '../sections/create-entra-client-secret.md';

# <IIcon icon="mdi:gitlab" height="48" /> Set up Maester in GitLab

This guide will walk you through setting up Maester in GitLab and automate the running of tests using GitLab Pipelines (jobs).

<!-- ## Why GitLab?

GitLab for personal projects (Free):
    400 compute minutes per month
    5 users per top-level group

--->

## Set up your Maester tests project (group) in GitLab

### Pre-requisites

- If you are new to GitLab, create an account at [gitlab.com](https://gitlab.com/-/trial_registrations/new) for organizations
- If you use GitLab.com, you can run your CI/CD jobs on [GitLab-hosted runners](https://docs.gitlab.com/runner/).

<!--
- Option A: GitLab for organizations [Premium, Ultimate] (https://about.gitlab.com/pricing/)
- Option B: GitLab for personal projects [Free]
- Option C: GitLab Dedicated (Self-Host)
-->

### Create a blank new project to always use the latest available public Maester Tests

- On the left sidebar, at the top, select 'Create new ()' and 'New project/repository'.
- Select [Create a blank project](https://docs.gitlab.com/ee/user/project/index.html#create-a-blank-project)

  Visibility Level: Private

<!--
### 2. Create a new project and import the Maester Tests repository, to keep updated yourself
 - private-tests = ToDo

1. On the left sidebar, at the top, select Create new () and New project/repository.
2. Select Import project.
3. Select the GitHub tab and Authenticate with GitHub
4. ... https://github.com/maester365/maester-tests...

- [Create a project from a built-in template](https://docs.gitlab.com/ee/user/project/index.html#create-a-project-from-a-built-in-template)

-->

There are many ways to authenticate with Microsoft Entra. We currently have tested client secrets, but there are probably more options available.

- <IIcon icon="material-symbols:password" height="18" /> **Client secret** uses a secret to authenticate with Microsoft Entra protected resources.

<Tabs>
<!--
<TabItem value="wif" label="Custom workflow using Workload identity federation" >
    ToBeTested ...
</TabItem>
-->
<TabItem value="cert" label="Custom workflow using client secret" default>

<CreateEntraApp/>

<CreateEntraClientSecret/>

### Create GitLab variables

- Open your `maester-tests` GitLab project and go to **Settings**
- Select **CI/CD** > **Variables** > **CI/CD Variables**
- Add the three secrets listed below by selecting **Add variable**
- To look up these values you will need to use the Entra portal, open the application you created earlier and copy the following values from the **Overview** page:
  - Visibility: Visible, Key: **AZURE_TENANT_NAME**, Value: The primary domain name of the Entra tenant
  - Visibility: Visible, Key: **AZURE_TENANT_ID**, Value: The Directory (tenant) ID of the Entra tenant
  - Visibility: Visible, Key: **AZURE_CLIENT_ID**, Value: The Application (client) ID of the Entra application you created
  - Visibility: Masked and hidden, Key: **AZURE_CLIENT_SECRET**, Value: The client secret you copied in the previous step
  - Visibility: Visible, Key: **CONNECTION_EXCHANGE**, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
  - Visibility: Visible, Key: **CONNECTION_IPP**, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
  - Visibility: Visible, Key: **CONNECTION_TEAMS**, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
- Save each secret by selecting **Add variable** at the bottom.

### Create .gitlab-ci.yml file (or use pipeline editor)

<!--
More Text
 - private-tests = ToDo
-->

```yaml
stages:
  - test

run_maester_tests_inline:
  stage: test
  image: mcr.microsoft.com/microsoftgraph/powershell:latest
  variables:
    TENANTID: $AZURE_TENANT_ID
    CLIENTID: $AZURE_CLIENT_ID
    CLIENTSECRET: $AZURE_CLIENT_SECRET
    CONNECTION_EXCHANGE: $CONNECTION_EXCHANGE
    CONNECTION_IPP: $CONNECTION_IPP
    CONNECTION_TEAMS: $CONNECTION_TEAMS

  before_script:
    - mkdir test-results
    - mkdir public-tests
    - pwsh -c 'Write-host "Running in project $env:CI_PROJECT_NAME with results at $env:CI_JOB_URL ($env:CI_JOB_URL)."'
  script:
    - |
      pwsh -Command '
        # Install Maester
        #Install-Module Maester -AllowPrerelease -Force
        Install-Module Maester -Force

        # Latest public tests
        Set-Location public-tests
        Install-MaesterTests
        Set-Location ..

        # Configure test results
        $PesterConfiguration = New-PesterConfiguration
        $PesterConfiguration.Output.Verbosity = "None"
        Write-Host "Pester verbosity level set to: $($PesterConfiguration.Output.Verbosity.Value)"

        $MaesterParameters = @{
            Path                 = "public-tests"
            PesterConfiguration  = $PesterConfiguration
            OutputFolder         = "test-results"
            OutputFolderFileName = "test-results"
            PassThru             = $true
        }

        $MaesterParameters.Add("DisableTelemetry", $false )
        Write-Host "Disable pester telemetry set to: $($MaesterParameters.DisableTelemetry)"

        $AdditionalConnections = @{
            Exchange      = [System.Convert]::ToBoolean($env:CONNECTION_EXCHANGE)
            IPP           = [System.Convert]::ToBoolean($env:CONNECTION_IPP)
            Teams         = [System.Convert]::ToBoolean($env:CONNECTION_TEAMS)
        }

        Write-Host "Additional connections configuration:"
        $AdditionalConnections.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)"
        }

        # Connect to Microsoft Graph
        $clientSecret = ConvertTo-SecureString -AsPlainText $env:AZURE_CLIENT_SECRET -Force
        [pscredential] $clientSecretCredential = New-Object System.Management.Automation.PSCredential($env:AZURE_CLIENT_ID, $clientSecret)
        Connect-MgGraph -TenantId $env:AZURE_TENANT_ID -ClientSecretCredential $clientSecretCredential -NoWelcome

        # Connect to Exchange Online and IPP
        Write-Host "Disable pester telemetry set to: $($MaesterParameters.DisableTelemetry)"
        if ($AdditionalConnections.Exchange -eq $true -or $AdditionalConnections.IPP -eq $true) {
            # Can be reduced after release from version 3.8.2
            if ($AdditionalConnections.Ipp -eq $false) {
                Install-Module -Name ExchangeOnlineManagement -Force
            } else {
                Install-Module -Name ExchangeOnlineManagement -Force -AllowPrereleas #-AllowPrereleas because accesstoken Auth to IPP is only allowed in 3.8.1-Preview1 and newer
            }

            $tokenBody = @{
                Grant_Type    = "client_credentials"
                Scope         = "https://outlook.office365.com/.default"
                Client_Id     = $env:AZURE_CLIENT_ID
                Client_Secret = $env:AZURE_CLIENT_SECRET

            }
            $tokenResponse = Invoke-RestMethod -Uri https://login.microsoftonline.com/$env:AZURE_TENANT_ID/oauth2/v2.0/token -Method POST -Body $tokenBody

            if ($AdditionalConnections.Exchange -eq $true) {
                Connect-ExchangeOnline -AccessToken $tokenResponse.access_token -Organization $env:AZURE_TENANT_NAME
            }

            if ($AdditionalConnections.Ipp -eq $true) {
                Connect-IPPSSession -AccessToken $tokenResponse.access_token -Organization $env:AZURE_TENANT_NAME
            }

        }

        # Connect to Microsoft Teams
        if ($AdditionalConnections.Teams -eq $true) {
            Install-Module -Name MicrosoftTeams -Force

            $graphtokenBody = @{
            Grant_Type    = "client_credentials"
            Scope         = "https://graph.microsoft.com/.default"
            Client_Id     = $env:AZURE_CLIENT_ID
            Client_Secret = $env:AZURE_CLIENT_SECRET
            }
            $graphToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$env:AZURE_TENANT_ID/oauth2/v2.0/token" -Method POST -Body $graphtokenBody | Select-Object -ExpandProperty Access_Token

            $teamstokenBody = @{
            Grant_Type    = "client_credentials"
            Scope         = "48ac35b8-9aa8-4d74-927d-1f4a14a0b239/.default"
            Client_Id     = $env:AZURE_CLIENT_ID
            Client_Secret = $env:AZURE_CLIENT_SECRET
            }
            $teamsToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$env:AZURE_TENANT_ID/oauth2/v2.0/token" -Method POST -Body $teamstokenBody | Select-Object -ExpandProperty Access_Token

            Connect-MicrosoftTeams -AccessTokens @("$graphToken", "$teamsToken")
        }

        # Run Maester tests
        #$results = Invoke-Maester -Path public-tests -PesterConfiguration $PesterConfiguration -OutputFolder test-results -OutputFolderFileName "test-results" -PassThru
        $results = Invoke-Maester @MaesterParameters

        # View summary report
        $results | Format-List Result, FailedCount, PassedCount, SkippedCount, TotalCount, TenantId, TenantName, CurrentVersion, LatestVersion

        # Flag status to GitLab
        if ($results.Result -ne "Passed") {
            Write-Warning "Status = $($results.Result): see Maester Test Report for details."
        }
      '
  after_script:
    - pwsh -c 'Write-host "Report can be opened at ($env:CI_JOB_URL/artifacts/external_file/test-results/test-results.html)."'
  artifacts:
    when: on_success
    paths:
      - test-results/
    expire_in: 1 week

  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" || $CI_PIPELINE_SOURCE == "web"'
```

  </TabItem>
  </Tabs>

## Manually running the Maester tests

To manually run the Maester tests workflow

- Open your `maester-tests` GitLab project and go to **Build**
- Select **Piplines** from the left pane
- Select **New pipline** on the right top button
- And again **New pipline** to run new pipeline

<!--
## Create a schedule (Optional)

Pipeline schedules are ...

- [Scheduled pipelines documentation](https://gitlab.com/help/ci/pipelines/schedules)
-->

## Viewing the test results

- Open your `maester-tests` GitLab project and go to **Build**
- Select **Artifacts** from the left pane
- Search a artifact to view the results e.g. `run_maester_tests_*`
- Select browse on the right to open the folder `test-results`

> **Summary view**
> A summary view is not available with GitLab in comparison to GitHub.

<!--
## FAQ / Troubleshooting
- Ensure you are monitoring your GitLab Runner cost
-->
