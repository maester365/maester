---
sidebar_label: GitHub
sidebar_position: 2
title: Set up Maester in GitHub
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import GraphPermissions from '../sections/permissions.md';
import CreateEntraApp from '../sections/create-entra-app.md';
import CreateEntraClientSecret from '../sections/create-entra-client-secret.md';
import EnableGitHubActionsCreateWorkflow from '../sections/enable-github-actions-workflow.md';

# <IIcon icon="mdi:github" height="48" /> Set up Maester in GitHub

This guide will walk you through setting up Maester in GitHub and automate the running of tests using GitHub Actions.

## Why GitHub?

GitHub is the quickest and easiest way to get started with automating Maester. The [free tier](https://github.com/pricing) includes 2,000 minutes per month for private repositories which is more than enough to run your Maester tests daily.

## Set up your Maester tests repository in GitHub

### Pre-requisites

- If you are new to GitHub, create an account at [github.com](https://github.com/join)

## Use the latest, or keep control of your versions?

You may want to always use the latest, or you may want to control the tests running each time. The two options below provide a choice for each.

### 1. Create a blank new repository to always use the latest available public Maester Tests

- Open [https://github.com/new](https://github.com/new)
- Fill in the following fields:
  - **Repository name**: E.g. `maester-tests`
  - **Add a README file**: Select this option to initialize your repository 
  - **Private**: Select this option to keep your tests private
- Select **Create repository**

### 2. Create a new repository and import the Maester Tests repository, to keep updated yourself

- Open [https://github.com/new/import](https://github.com/new/import)
- Fill in the following fields:
  - **Your old repository’s clone URL**: `https://github.com/maester365/maester-tests`
  - **Repository name**: E.g. `maester-tests`
  - **Private**: Select this option to keep your tests private
- Select **Begin Import**

## Set up the GitHub Actions workflow

There are many ways to authenticate with Microsoft Entra from GitHub Actions. We recommend using [**workload identity federation**](https://learn.microsoft.com/entra/workload-id/workload-identity-federation) as it is more secure, requires less maintenance and is the easiest to set up.

If you’re unable to use more advanced options like certificates stored in Azure Key Vault, which need an Azure subscription, there’s also guidance available for using client secrets.

- <IIcon icon="gravity-ui:nut-hex" height="18" /> **Workload identity federation** (recommended) uses OpenID Connect (OIDC) to authenticate with Microsoft Entra protected resources without using secrets.
- <IIcon icon="material-symbols:password" height="18" /> **Client secret** uses a secret to authenticate with Microsoft Entra protected resources.

<Tabs>
  <TabItem value="gha-wif" label="GitHub Action using Workload identity federation (recommended)" default>

This guide is based on [Use GitHub Actions to connect to Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure) and uses the maester GitHub action.

### Pre-requisites

<CreateEntraApp/>

### Add federated credentials

- Select **Certificates & secrets**
- Select **Federated credentials**, select **Add credential**
- For **Federated credential scenario**, select **GitHub Actions deploying Azure resources**
- Fill in the following fields
  - **Organization**: Your GitHub organization name or GitHub username. E.g. `jasonf`
  - **Repository**: Your GitHub repository name (from the previous step). E.g. `maester-tests`
  - **Entity type**: `Branch`
  - **GitHub branch name**: `main`
  - **Credential details** > **Name**: E.g. `maester-devops`
- Select **Add**

### Create GitHub secrets

- Open your `maester-tests` GitHub repository and go to **Settings**
- Select **Security** > **Secrets and variables** > **Actions**
- Add the secrets listed below by selecting **New repository secret**
- To look up these values you will need to use the Entra portal, open the application you created earlier and copy the following values from the **Overview** page:
  - Name: **AZURE_TENANT_ID**, Value: The Directory (tenant) ID of the Entra tenant
  - Name: **AZURE_CLIENT_ID**, Value: The Application (client) ID of the Entra application you created
- Save each secret by selecting **Add secret**.

<EnableGitHubActionsCreateWorkflow/>

```yaml
name: Maester Daily Tests

on:
  push:
    branches: ["main"]
  # Run once a day at midnight
  schedule:
    - cron: "0 0 * * *"
  # Allows to run this workflow manually from the Actions tab
  workflow_dispatch:

permissions:
      id-token: write
      contents: read
      checks: write

jobs:
  run-maester-tests:
    name: Run Maester Tests
    runs-on: ubuntu-latest
    steps:
    - name: Run Maester action
      uses: maester365/maester@main
      with:
        client_id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant_id: ${{ secrets.AZURE_TENANT_ID }}
        include_public_tests: true # Optional: Set to false if you are keeping to a certain version of tests or have your own tests
        step_summary: true         # Optional: Set to false if you don't want a summary added to your GitHub Action run
        artifact_upload: true      # Optional: Set to false if you don't want summaries uploaded to GitHub Artifacts
        # Other inputs are available and can be reviewed in the action.yml in the Maester repository

```

  </TabItem>
  <TabItem value="wif" label="Custom workflow using Workload identity federation" default>

This guide is based on [Use GitHub Actions to connect to Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure)

### Pre-requisites

- An Azure subscription is required for this method. This Azure subscription is required to set up workload identity federation authentication. No Azure resources will be created and there are no costs associated with it.
  - If you don't have an Azure subscription, you can create one by following [Create a Microsoft Customer Agreement subscription](https://learn.microsoft.com/azure/cost-management-billing/manage/create-subscription) or ask your Azure administrator to create one.

<CreateEntraApp/>

### Add federated credentials

- Select **Certificates & secrets**
- Select **Federated credentials**, select **Add credential**
- For **Federated credential scenario**, select **GitHub Actions deploying Azure resources**
- Fill in the following fields
  - **Organization**: Your GitHub organization name or GitHub username. E.g. `jasonf`
  - **Repository**: Your GitHub repository name (from the previous step). E.g. `maester-tests`
  - **Entity type**: `Branch`
  - **GitHub branch name**: `main`
  - **Credential details** > **Name**: E.g. `maester-devops`
- Select **Add**

### Create GitHub secrets

- Open your `maester-tests` GitHub repository and go to **Settings**
- Select **Security** > **Secrets and variables** > **Actions**
- Add the secrets listed below by selecting **New repository secret**
- To look up these values you will need to use the Entra portal, open the application you created earlier and copy the following values from the **Overview** page:
  - Name: **AZURE_TENANT_ID**, Value: The Directory (tenant) ID of the Entra tenant
  - Name: **AZURE_CLIENT_ID**, Value: The Application (client) ID of the Entra application you created
- Save each secret by selecting **Add secret**.

<EnableGitHubActionsCreateWorkflow/>

```yaml
name: Maester Daily Tests

on:
  push:
    branches: ["main"]
  # Run once a day at midnight
  schedule:
    - cron: "0 0 * * *"
  # Allows to run this workflow manually from the Actions tab
  workflow_dispatch:

permissions:
      id-token: write
      contents: read
      checks: write

jobs:
  run-maester-tests:
    name: Run Maester Tests
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Set current date as env variable
      run: echo "NOW=$(date +'%Y-%m-%d-T%H%M%S')" >> $GITHUB_ENV
    - name: 'Az CLI login'
      uses: azure/login@v2
      with:
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          allow-no-subscriptions: true
    - name: Run Maester
      uses: azure/powershell@v2
      with:
        inlineScript: |
          # Get Token
          $token = az account get-access-token --resource-type ms-graph

          # Connect to Microsoft Graph
          $accessToken = ($token | ConvertFrom-Json).accessToken | ConvertTo-SecureString -AsPlainText -Force
          Connect-MgGraph -AccessToken $accessToken

          # Install Maester
          Install-Module Maester -Force

          # Configure test results
          $PesterConfiguration = New-PesterConfiguration
          $PesterConfiguration.Output.Verbosity = 'None'

          # Run Maester tests
          $results = Invoke-Maester -Path tests/Maester/ -PesterConfiguration $PesterConfiguration -OutputFolder test-results -OutputFolderFileName "test-results" -PassThru

          # Add step summary
          $summary = Get-Content test-results/test-results.md
          Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $summary

          # Flag status to GitHub - Uncomment the block below to fail the build if tests fail
          #if ($results.Result -ne 'Passed'){
          #  Write-Error "Status = $($results.Result): See Maester Test Report below for details."
          #}
        azPSVersion: "latest"

    - name: Archive Maester Html Report
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: maester-test-results-${{ env.NOW }}
        path: test-results
```

  </TabItem>
  <TabItem value="cert" label="Custom workflow using Client secret">

<CreateEntraApp/>

<CreateEntraClientSecret/>

### Create GitHub secrets

- Open your `maester-tests` GitHub repository and go to **Settings**
- Select **Security** > **Secrets and variables** > **Actions**
- Add the three secrets listed below by selecting **New repository secret**
- To look up these values you will need to use the Entra portal, open the application you created earlier and copy the following values from the **Overview** page:
  - Name: **AZURE_TENANT_ID**, Value: The Directory (tenant) ID of the Entra tenant
  - Name: **AZURE_CLIENT_ID**, Value: The Application (client) ID of the Entra application you created
  - Name: **AZURE_CLIENT_SECRET**, Value: The client secret you copied in the previous step
- Save each secret by selecting **Add secret**.

<EnableGitHubActionsCreateWorkflow/>

```yaml
name: Maester Daily Tests

on:
  push:
    branches: ["main"]
  # Run once a day at midnight
  schedule:
    - cron: "0 0 * * *"
  # Allows to run this workflow manually from the Actions tab
  workflow_dispatch:

permissions:
      id-token: write
      contents: read
      checks: write

jobs:
  run-maester-tests:
    name: Run Maester Tests
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Set current date as env variable
      run: echo "NOW=$(date +'%Y-%m-%d-T%H%M%S')" >> $GITHUB_ENV
    - name: Run Maester
      shell: pwsh
      env:
        TENANTID: ${{ secrets.AZURE_TENANT_ID }}
        CLIENTID: ${{ secrets.AZURE_CLIENT_ID }}
        CLIENTSECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
      run: |
        # Connect to Microsoft Graph
        $clientSecret = ConvertTo-SecureString -AsPlainText $env:CLIENTSECRET -Force
        [pscredential]$clientSecretCredential = New-Object System.Management.Automation.PSCredential($env:CLIENTID, $clientSecret)
        Connect-MgGraph -TenantId $env:TENANTID -ClientSecretCredential $clientSecretCredential

        # Install Maester
        Install-Module Maester -Force

        # Configure test results
        $PesterConfiguration = New-PesterConfiguration
        $PesterConfiguration.Output.Verbosity = 'None'

        # Run Maester tests
        $results = Invoke-Maester -Path tests/Maester/ -PesterConfiguration $PesterConfiguration -OutputFolder test-results -OutputFolderFileName "test-results" -PassThru

        # Add step summary
        $summary = Get-Content test-results/test-results.md
        Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $summary

        # Flag status to GitHub - Uncomment the block below to fail the build if tests fail
        #if ($results.Result -ne 'Passed'){
        #  Write-Error "Status = $($results.Result): See Maester Test Report below for details."
        #}

    - name: Archive Maester Html Report
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: maester-test-results-${{ env.NOW }}
        path: test-results
```

### Step-by-step video tutorial

<iframe width="686" height="386" src="https://www.youtube.com/embed/SzIxCQg6CWA" title="Maester Github Actions integration" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

  </TabItem>
  </Tabs>

## Manually running the Maester tests

To manually run the Maester tests workflow

- Open your `maester-tests` GitHub repository and go to **Actions**
- Select **Maester Daily Tests** from the left pane
- Select **Run workflow** drop-down from the right pane
- Select **Run workflow** button to start the workflow
- Select the running workflow to view the status

## Viewing test results

- Open your `maester-tests` GitHub repository and go to **Actions**
- Select a workflow run to view the results e.g. `Maester Daily Tests`

### Summary view

The summary view shows the status of the workflow run, the duration, and the number of tests that passed, failed, and were skipped.

![Screenshot of GitHub worklflow run summary Page](assets/github-summary-page.png)

### Maester report

The detailed Maester report can be downloaded by selecting the **maester-test-results...** file from the **Artifacts** section and opening the `test-results.html` page.

![Screenshot of the downloaded Maester report](assets/github-maester-report.png)

### Summary Maester report

A detailed summary of the Maester report can be viewed by scrolling down **Summary** page.

![Screenshot of Maester report in the GitHub Summary Page](assets/github-summary-details.png)

### Logs view

Select the **Run Maester Tests** job from **Jobs** in the left pane to view the raw logs.

![Screenshot of GitHub workflow logs page](assets/github-logs-page.png)

## Keeping your Maester tests up to date

The Maester team will add new tests over time. To get the latest updates, use the commands below to update your GitHub repository with the latest tests.

- Clone your fork of the **maester-tests** repository to your local computer. See [Cloning a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository).
- Update the `Maester` PowerShell module to the latest version and load it.
- Change to the `maester-tests\tests` directory.
- Run `Update-MaesterTests`.

```powershell
cd maester-tests\tests

Update-Module Maester -Force
Import-Module Maester
Update-MaesterTests
```
