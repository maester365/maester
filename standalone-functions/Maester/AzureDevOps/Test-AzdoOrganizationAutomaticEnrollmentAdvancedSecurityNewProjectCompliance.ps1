function Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProjectCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if GitHub advanced Security for Azure DevOps is automatically enabled for new projects.

    https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml#organization-level-onboarding
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProjectCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Running Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProject"

    $result = (Get-ADOPSOrganizationAdvancedSecurity).enableOnCreate

    if ($result) {
        $resultMarkdown = "New projects will by default have Advanced Security enabled."
    } else {
        $resultMarkdown = "New projects must be manually enrolled in Advanced Security."
    }


    return $result

}
