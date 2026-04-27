<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if classic release pipelines can be created.

    https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines

.EXAMPLE
    ```
    Test-AzdoOrganizationCreationClassicReleasePipeline
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationCreationClassicReleasePipeline
#>
function Test-AzdoOrganizationCreationClassicReleasePipeline {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Insufficient permissions to access the pipeline settings API. Please ensure you have the necessary permissions to access this information.'
        return $null
    }

    $result = $settings.disableClassicReleasePipelineCreation

    if (-not $result) {
        $resultMarkdown = "Classic release pipelines, task groups, and deployment groups can be created / imported."
    } else {
        $resultMarkdown = "No classic release pipelines, task groups, and deployment groups can be created / imported. Existing ones will continue to work."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return -not $result
}
