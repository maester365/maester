<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of anonymous status badges in Azure DevOps.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/create-first-pipeline?view=azure-devops&tabs=net%2Cbrowser#add-a-status-badge-to-your-repository

.EXAMPLE
    ```
    Test-AzdoOrganizationBadgesArePrivate
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationBadgesArePrivate
#>

function Test-AzdoOrganizationBadgesArePrivate {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationBadgesArePrivate"

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Insufficient permissions to access the pipeline settings API. Please ensure you have the necessary permissions to access this information.'
        return $null
    }

    $result = $settings.statusBadgesArePrivate

    if ($result) {
        $resultMarkdown = "Azure DevOps badges are private."
    } else {
        $resultMarkdown = "Anonymous users can access the status badge API for all pipelines."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
