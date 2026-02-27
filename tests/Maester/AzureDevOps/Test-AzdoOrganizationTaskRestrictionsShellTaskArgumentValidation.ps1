<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status if the Enable shell tasks arguments validation setting that validates argument parameters for built-in shell tasks to check for inputs that can inject commands into scripts.
    The check ensures that the shell correctly executes characters like semicolons, quotes, and parentheses.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#shellTasksValidation

.EXAMPLE
    ```
    Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation
#>
function Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enableShellTasksArgsSanitizing

    if ($result) {
        $resultMarkdown = "Argument parameters for built-in shell tasks are validated to check for inputs that can inject commands into scripts."
    } else {
        $resultMarkdown = "Argument parameters for built-in shell tasks may inject commands into scripts."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
