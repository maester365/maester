function Test-AzdoResourceUsageWorkItemTags {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $WorkItemTags = (Get-ADOPSResourceUsage).'Work Item Tags'

    $CurrentUsage = $($WorkItemTags.count / $WorkItemTags.limit).Tostring("P")

    if ($($WorkItemTags.count / $WorkItemTags.limit) -gt 0.9) {
        $resultMarkdown = "Work Item Tags Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    }
    else {
        $resultMarkdown = "Well done. Work Item Tags Resource Usage limit is at $CurrentUsage"
        $result = $true
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown   -Severity 'High'

    return $result
}
