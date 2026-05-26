function Test-AzdoResourceUsageWorkItemTagCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status of the usage of tag definitions in Azure DevOps, as Azure DevOps supports up to 150,000 tag definitions per organization or collection.

    https://learn.microsoft.com/en-us/azure/devops/organizations/settings/work/object-limits?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoResourceUsageWorkItemTagCompliance
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
    Write-Verbose "Running Test-AzdoResourceUsageWorkItemTag"


    $WorkItemTags = (Get-ADOPSResourceUsage -Force).'Work Item Tags'

    $CurrentUsage = $($WorkItemTags.count / $WorkItemTags.limit).ToString("P")

    if ($($WorkItemTags.count / $WorkItemTags.limit) -gt 0.9) {
        $resultMarkdown = "Work Item Tags Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    } else {
        $resultMarkdown = "Work Item Tags Resource Usage limit is at $CurrentUsage"
        $result = $true
    }


    return $result

}
