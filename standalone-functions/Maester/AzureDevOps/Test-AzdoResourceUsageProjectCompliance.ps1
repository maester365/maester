function Test-AzdoResourceUsageProjectCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status of limitation regarding projects in Azure DevOps, As it supports up to 1,000 projects within an organization

    https://learn.microsoft.com/en-us/azure/devops/organizations/projects/about-projects?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoResourceUsageProjectCompliance
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
    Write-Verbose "Running Test-AzdoResourceUsageProject"


    $Projects = (Get-ADOPSResourceUsage -Force).Projects

    $CurrentUsage = $($Projects.count / $Projects.limit).ToString("P")

    if ($($Projects.count / $Projects.limit) -gt 0.9) {
        $resultMarkdown = "Project Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    } else {
        $resultMarkdown = "Project Resource Usage limit is at $CurrentUsage"
        $result = $true
    }


    return $result

}
