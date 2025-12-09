function Test-AzdoResourceUsageProjects {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $Projects = (Get-ADOPSResourceUsage).Projects

    $CurrentUsage = $($Projects.count / $Projects.limit).Tostring("P")

    if ($($Projects.count / $Projects.limit) -gt 0.9) {
        $resultMarkdown = "Project Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    }
    else {
        $resultMarkdown = "Well done. Project Resource Usage limit is at $CurrentUsage"
        $result = $true
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown   -Severity 'High'

    return $result
}
