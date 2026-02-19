<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if GitHub advanced Security for Azure DevOps is automatically enabled for new projects.

    https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml#organization-level-onboarding

.EXAMPLE
    ```
    Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProject
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProject
#>

function Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProject {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
        break
    }
    $result = (Get-ADOPSOrganizationAdvancedSecurity).enableOnCreate

    if ($result) {
        $resultMarkdown = "Well done. New projects will by default have Advanced Security enabled."
    } else {
        $resultMarkdown = "New projects must be manually enrolled in Advanced Security."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
