<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if repositories in the organization are allowed to use GitHub Copilot code review.

    GitHub Copilot code review is a preview feature. The organization level setting has no documented REST
    API and is only exposed through the contribution data provider that the Organization settings >
    Repositories page calls, so this test posts to the HierarchyQuery endpoint and reads the
    'ms.vss-code-web.copilot-code-review-org-settings-data-provider' provider.

    The setting is read from the data provider rather than from the SourceControl.GitPullRequests.CopilotReview
    feature flag returned alongside it, because feature flags describe rollout state rather than configuration.

    Requires permission to view the organization repository settings.

.EXAMPLE
    ```
    Test-AzdoOrganizationCopilotCodeReview
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationCopilotCodeReview
#>
function Test-AzdoOrganizationCopilotCodeReview {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationCopilotCodeReview"

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $Organization = (Get-ADOPSConnection).Organization
    $Uri = "https://dev.azure.com/$Organization/_apis/Contribution/HierarchyQuery?api-version=7.1-preview"
    $Body = '{
        "contributionIds": [
            "ms.vss-code-web.settings-options"
        ]
    }'

    $Response = $null
    $RequestError = $null
    try {
        $Response = Invoke-ADOPSRestMethod -Uri $Uri -Method Post -Body $Body
    } catch {
        $RequestError = $_
    }

    if ($null -ne $RequestError) {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $RequestError
        return $null
    }

    $Setting = $Response.dataProviders.'ms.vss-code-web.copilot-code-review-org-settings-data-provider'

    if ($null -eq $Setting) {
        $Message = "The Copilot code review organization settings data provider was not returned. The signed in identity may lack permission to view the organization repository settings."
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    # The provider is returned whether or not the organization is in the preview, and reports isEnabled=false
    # in both cases. This feature flag is the only signal that distinguishes "not onboarded to the preview"
    # from "onboarded but switched off", so it gates availability rather than supplying the setting itself.
    $Available = $Response.dataProviderSharedData._featureFlags.'SourceControl.GitPullRequests.CopilotReview'

    if ($false -eq $Available) {
        $Message = "GitHub Copilot code review is in limited public preview and this organization has not been onboarded to it, so the setting cannot be turned on yet. Organizations can request access by [signing up for the preview](https://nam.dcv.ms/VeDNq3VRhX). See [Copilot code reviews for Azure Repos](https://learn.microsoft.com/azure/devops/release-notes/2026/sprint-275-update#copilot-code-reviews-for-azure-repos-limited-public-preview)."
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    $result = [bool]$Setting.isEnabled

    if ($result) {
        $resultMarkdown = "Repositories in your organization are allowed to use GitHub Copilot code review.`n`n"
    } else {
        $resultMarkdown = "**Not allowed: Copilot code review for the organization.**`n`nNo repository can enable it until the organization level setting is turned on.`n`n"
    }

    $resultMarkdown += "| Setting | Value |`n"
    $resultMarkdown += "| --- | --- |`n"
    $resultMarkdown += "| Copilot code review allowed | $(if ($result) { 'True' } else { '**False**' }) |`n"
    if ($null -ne $Setting.agentPoolId) {
        $resultMarkdown += "| Agent pool ID | $($Setting.agentPoolId) |`n"
    }

    if (-not $result) {
        $resultMarkdown += "`nThis organization is onboarded to the preview, so the setting can be turned on in **Organization settings** > **Repos** > **Repositories**.`n"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
