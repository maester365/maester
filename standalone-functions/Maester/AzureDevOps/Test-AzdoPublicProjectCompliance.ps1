function Test-AzdoPublicProjectCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status of public projects within your Azure DevOps Organization.

    https://aka.ms/vsts-anon-access
    https://learn.microsoft.com/en-us/azure/devops/organizations/projects/make-project-public?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoPublicProjectCompliance
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
    Write-Verbose "Running Test-AzdoPublicProject"


    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.AllowAnonymousAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your Azure DevOps tenant allows the creation and use of public projects"
    } else {
        $resultMarkdown = "Your tenant has disabled the use of public projects"
    }


    return $result

}
