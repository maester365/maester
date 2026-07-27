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
  - **Repository name**: E.g. `maester-tests`
  - **Private**: Select this option to keep your tests private

<!--
### 2. Create a new project and import the Maester Tests repository, to keep updated yourself
 - private-tests = ToDo

1. On the left sidebar, at the top, select Create new () and New project/repository.
2. Select Import project.
3. Select the GitHub tab and Authenticate with GitHub
4. ... https://github.com/maester365/maester-tests...

- [Create a project from a built-in template](https://docs.gitlab.com/ee/user/project/index.html#create-a-project-from-a-built-in-template)

-->

There are many ways to authenticate with Microsoft Entra from GitHub Actions. We recommend using [**workload identity federation**](https://learn.microsoft.com/entra/workload-id/workload-identity-federation) as it is more secure, requires less maintenance and is the easiest to set up.

If you’re unable to use more advanced options like certificates stored in Azure Key Vault, which need an Azure subscription, there’s also guidance available for using client secrets.

- <IIcon icon="gravity-ui:nut-hex" height="18" /> **Workload identity federation** (recommended) uses OpenID Connect (OIDC) to authenticate with Microsoft Entra protected resources without using secrets.
- <IIcon icon="material-symbols:password" height="18" /> **Client secret** uses a secret to authenticate with Microsoft Entra protected resources.

<Tabs>

<TabItem value="wif" label="GitLab Pipline Workload identity federation (recommended)" default>

<CreateEntraApp/>

### Add federated credentials

- Select **Certificates & secrets**
- Select **Federated credentials**, select **Add credential**
- For **Federated credential scenario**, select **Other issuer**
- Fill in the following fields
  - **Issuer**: Your GitLab organization url or standard gitlab url `https://gitlab.com`
  - **Type**: Select **Explicit subject identifier**
  - **Value**: `project_path:<mygroup>/<myproject>:ref_type:branch:ref:<branch>` E.g. `project_path:maester/maester-tests:ref_type:branch:ref:main`
  - **Name**: Credential name E.g. `gitlab-federated-identity`
  - **Description**: Credential name E.g. `GitLab service account federated identity`
  - **Audience**: Your GitLab organization url or standard gitlab url `https://gitlab.com`
- Select **Add**

> **📖 For detailed Azure integration guidance:** GitLab provides comprehensive documentation on integrating with Azure services. See the [GitLab Azure integration guide](https://docs.gitlab.com/ci/cloud_services/azure/) for advanced authentication patterns, best practices, and troubleshooting tips.


### Create GitLab variables

- Open your `maester-tests` GitLab project and go to **Settings**
- Select **CI/CD** > **Variables** > **CI/CD Variables**
- Add the three secrets listed below by selecting **Add variable**
- To look up these values you will need to use the Entra portal, open the application you created earlier and copy the following values from the **Overview** page:
  - Visibility: **Visible**, Key: `AZURE_TENANT_ID`, Value: The Directory (tenant) ID of the Entra tenant
  - Visibility: **Visible**, Key: `AZURE_CLIENT_ID`, Value: The Application (client) ID of the Entra application you created
- Define which services should be connected using the other variables in order to run the corresponding tests.
  - Visibility: **Visible**, Key: `CONNECTION_EXCHANGE`, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
  - Visibility: **Visible**, Key: `CONNECTION_PURVIEW`, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
  - Visibility: **Visible**, Key: `CONNECTION_TEAMS`, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
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
  id_tokens:
    AZURE_FEDERATED_TOKEN:
      aud: https://gitlab.com
  variables:
    TENANTID: $AZURE_TENANT_ID
    CLIENTID: $AZURE_CLIENT_ID
    CONNECTION_EXCHANGE: $CONNECTION_EXCHANGE
    CONNECTION_PURVIEW: $CONNECTION_PURVIEW
    CONNECTION_TEAMS: $CONNECTION_TEAMS

  before_script:
    - mkdir test-results
    - mkdir public-tests
    - pwsh -c 'Write-host "Running in project $env:CI_PROJECT_NAME with results at $env:CI_JOB_URL ($env:CI_JOB_URL)."'
  script:
    - |
      pwsh -Command '
        #region prepare execution
        # Install Maester
        #Install-Module Maester -AllowPrerelease -Force
        Install-Module Maester -Force
        Install-Module Az.Accounts -Force

        # Latest public tests
        Set-Location public-tests
        Install-MaesterTests
        Set-Location ..


        # Declare functions
        function Get-AccessToken {
            param([string]$Scope)

            $TokenBody = @{
                grant_type            = "client_credentials"
                client_id             = $env:AZURE_CLIENT_ID
                client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
                client_assertion      = $env:AZURE_FEDERATED_TOKEN.Trim()
                scope                 = $Scope
            }

            $Response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$env:AZURE_TENANT_ID/oauth2/v2.0/token" -Method POST -Body $TokenBody -ContentType "application/x-www-form-urlencoded"
            return $Response.access_token
        }

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
            Purview       = [System.Convert]::ToBoolean($env:CONNECTION_PURVIEW)
            Teams         = [System.Convert]::ToBoolean($env:CONNECTION_TEAMS)
        }

        Write-Host "Additional connections configuration:"
        $AdditionalConnections.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)"
        }

        #endregion prepare execution
        #region connect to services

        # Connect as service principal
        Write-Host "Connect service principal"
        Connect-AzAccount -ServicePrincipal -Tenant $env:AZURE_TENANT_ID -ApplicationId $env:AZURE_CLIENT_ID -FederatedToken $env:AZURE_FEDERATED_TOKEN | Out-Null

        # Get Graph token and connect to Microsoft Graph
        Write-Host "Connect Graph"
        $graphToken = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token
        Connect-MgGraph -AccessToken $graphToken -NoWelcome

        # Connect to Exchange Online and Purview
        if ($AdditionalConnections.Exchange -eq $true -or $AdditionalConnections.Purview -eq $true) {
            Install-Module -Name ExchangeOnlineManagement -Force

            # Get Exchange Online token using Az authentication
            $exchangeToken = Get-AccessToken -Scope "https://outlook.office365.com/.default"

            if ($AdditionalConnections.Exchange -eq $true) {
                Write-Host "Connect Exchange"
                Connect-ExchangeOnline -AccessToken $exchangeToken -Organization $env:AZURE_TENANT_ID -ShowBanner:$false
            }

            if ($AdditionalConnections.Purview -eq $true) {
              $domains = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/domains?`$select=id,isDefault"
              $primaryDomain = $domains.value | Where-Object { $_.isDefault -eq $true } | Select-Object -ExpandProperty id

              Write-Host "Connect Purview"
              Connect-IPPSSession -AccessToken $exchangeToken -Organization $primaryDomain -ShowBanner:$false
            }
        }

        # Connect to Microsoft Teams
        if ($AdditionalConnections.Teams -eq $true) {
            Install-Module -Name MicrosoftTeams -Force

            Write-Host "Connect Teams"

            # Get Graph token using federated credentials
            $graphToken = Get-AccessToken -Scope "https://graph.microsoft.com/.default"

            # Get Teams token using federated credentials
            $teamsToken = Get-AccessToken -Scope "48ac35b8-9aa8-4d74-927d-1f4a14a0b239/.default"  # Microsoft Teams Application ID

            # Connect to Microsoft Teams with both tokens
            Connect-MicrosoftTeams -AccessTokens @("$graphToken", "$teamsToken")
        }

        #endregion connect to services

        #region run tests

        # Run Maester tests
        #$results = Invoke-Maester -Path public-tests -PesterConfiguration $PesterConfiguration -OutputFolder test-results -OutputFolderFileName "test-results" -PassThru
        $results = Invoke-Maester @MaesterParameters

        #endregion run tests
        #region end script

        # View summary report
        $results | Format-List Result, FailedCount, PassedCount, SkippedCount, TotalCount, TenantId, TenantName, CurrentVersion, LatestVersion

        # Flag status to GitLab
        if ($results.Result -ne "Passed") {
            Write-Warning "Status = $($results.Result): see Maester Test Report for details."
        }
        #endregion end script
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
<TabItem value="secret" label="Custom workflow using client secret" default>

<CreateEntraApp/>

<CreateEntraClientSecret/>

### Create GitLab variables

- Open your `maester-tests` GitLab project and go to **Settings**
- Select **CI/CD** > **Variables** > **CI/CD Variables**
- Add the three secrets listed below by selecting **Add variable**
- To look up these values you will need to use the Entra portal, open the application you created earlier and copy the following values from the **Overview** page:
  - Visibility: **Visible**, Key: `AZURE_TENANT_ID`, Value: The Directory (tenant) ID of the Entra tenant
  - Visibility: **Visible**, Key: `AZURE_CLIENT_ID`, Value: The Application (client) ID of the Entra application you created
  - Visibility: **Masked and hidden**, Key: `AZURE_CLIENT_SECRET`, Value: The client secret you copied in the previous step
- Define which services should be connected using the other variables in order to run the corresponding tests.
  - Visibility: **Visible**, Key: `CONNECTION_EXCHANGE`, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
  - Visibility: **Visible**, Key: `CONNECTION_PURVIEW`, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
  - Visibility: **Visible**, Key: `CONNECTION_TEAMS`, Value: "true" if you want to connect to the service and execute tests for this service too, "false" if not
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
    CONNECTION_PURVIEW: $CONNECTION_PURVIEW
    CONNECTION_TEAMS: $CONNECTION_TEAMS

  before_script:
    - mkdir test-results
    - mkdir public-tests
    - pwsh -c 'Write-host "Running in project $env:CI_PROJECT_NAME with results at $env:CI_JOB_URL ($env:CI_JOB_URL)."'
  script:
    - |
      pwsh -Command '
        #region prepare execution
        # Install Maester
        #Install-Module Maester -AllowPrerelease -Force
        Install-Module Maester -Force

        # Latest public tests
        Set-Location public-tests
        Install-MaesterTests
        Set-Location ..

        # Declare functions
        function Get-AccessToken {
            param([string]$Scope)

            $TokenBody = @{
                Grant_Type    = "client_credentials"
                Scope         = $Scope
                Client_Id     = $env:AZURE_CLIENT_ID
                Client_Secret = $env:AZURE_CLIENT_SECRET
            }
            $Response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$env:AZURE_TENANT_ID/oauth2/v2.0/token" -Method POST -Body $TokenBody -ContentType "application/x-www-form-urlencoded"
            return $Response.access_token
        }

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
            Purview       = [System.Convert]::ToBoolean($env:CONNECTION_PURVIEW)
            Teams         = [System.Convert]::ToBoolean($env:CONNECTION_TEAMS)
        }

        Write-Host "Additional connections configuration:"
        $AdditionalConnections.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)"
        }

        # Connect to Microsoft Graph
        Write-Host "Connect Graph"
        $clientSecret = ConvertTo-SecureString -AsPlainText $env:AZURE_CLIENT_SECRET -Force
        [pscredential] $clientSecretCredential = New-Object System.Management.Automation.PSCredential($env:AZURE_CLIENT_ID, $clientSecret)
        Connect-MgGraph -TenantId $env:AZURE_TENANT_ID -ClientSecretCredential $clientSecretCredential -NoWelcome

        # Connect to Exchange Online and Purview
        if ($AdditionalConnections.Exchange -eq $true -or $AdditionalConnections.Purview -eq $true) {
            Install-Module -Name ExchangeOnlineManagement -Force

            # Get Exchange Online token using
            $exchangeToken = Get-AccessToken -Scope "https://outlook.office365.com/.default"

            if ($AdditionalConnections.Exchange -eq $true) {
                Write-Host "Connect Exchange"
                Connect-ExchangeOnline -AccessToken $exchangeToken -Organization $env:AZURE_TENANT_ID -ShowBanner:$false
            }

            if ($AdditionalConnections.Purview -eq $true) {
              $domains = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/domains?`$select=id,isDefault"
              $primaryDomain = $domains.value | Where-Object { $_.isDefault -eq $true } | Select-Object -ExpandProperty id

              Write-Host "Connect Purview"
              Connect-IPPSSession -AccessToken $exchangeToken -Organization $primaryDomain -ShowBanner:$false
            }

        }

        # Connect to Microsoft Teams
        if ($AdditionalConnections.Teams -eq $true) {
            Install-Module -Name MicrosoftTeams -Force

            Write-Host "Connect Teams"

            # Get Graph token using federated credentials
            $graphToken = Get-AccessToken -Scope "https://graph.microsoft.com/.default"

            # Get Teams token using federated credentials
            $teamsToken = Get-AccessToken -Scope "48ac35b8-9aa8-4d74-927d-1f4a14a0b239/.default"  # Microsoft Teams Application ID

            Connect-MicrosoftTeams -AccessTokens @("$graphToken", "$teamsToken")
        }

        #endregion connect to services
        #region run tests

        # Run Maester tests
        #$results = Invoke-Maester -Path public-tests -PesterConfiguration $PesterConfiguration -OutputFolder test-results -OutputFolderFileName "test-results" -PassThru
        $results = Invoke-Maester @MaesterParameters

        #endregion run tests
        #region end script

        # View summary report
        $results | Format-List Result, FailedCount, PassedCount, SkippedCount, TotalCount, TenantId, TenantName, CurrentVersion, LatestVersion

        # Flag status to GitLab
        if ($results.Result -ne "Passed") {
            Write-Warning "Status = $($results.Result): see Maester Test Report for details."
        }
        #endregion end script
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
