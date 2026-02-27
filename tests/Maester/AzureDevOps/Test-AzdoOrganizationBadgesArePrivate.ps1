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

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).statusBadgesArePrivate

    if ($result) {
        $resultMarkdown = "Azure DevOps badges are private."
    } else {
        $resultMarkdown = "Anonymous users can access the status badge API for all pipelines."
    }

    Add-MtTestResultDetail -Result $resultMarkdown
    return $result
}
