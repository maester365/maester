<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if user defined variables are able to override system variables or variables not defined by the pipeline author.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#limit-variables-that-can-be-set-at-queue-time

.EXAMPLE
    ```
    Test-AzdoOrganizationLimitVariablesAtQueueTime
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationLimitVariablesAtQueueTime
#>
function Test-AzdoOrganizationLimitVariablesAtQueueTime {
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

    $result = $settings.enforceSettableVar

    if ($result) {
        $resultMarkdown = "With this option enabled, only those variables that are explicitly marked as ""Settable at queue time"" can be set"
    } else {
        $auditEnforceSettableVar = $settings.auditEnforceSettableVar
        if ($auditEnforceSettableVar) {
            $resultMarkdown = "Auditing is configured, however usage is not restricted."
        } else {
            $resultMarkdown = "Users can define new variables not defined by pipeline author, and may override system variables."
        }
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
