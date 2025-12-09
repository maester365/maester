function Test-AzdoOrganizationOwner {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw
    
    $Data = Get-ADOPSOrganizationAdminOverview
    if ($data.'ms.vss-admin-web.organization-admin-overview-delay-load-data-provider'.exceptionType -eq 'AadGraphException') {
        $resultMarkdown = "Workload identities cannot fetch Organization Owner."
        Add-MtTestResultDetail -Result "BUG: Workload identities cannot fetch Organization Owner." -SkippedCustomReason "Workload identities cannot fetch Organization Owner." -SkippedBecause Custom 
        $result = $false
    }
    else {
        $currentOwner = $data.'ms.vss-admin-web.organization-admin-overview-delay-load-data-provider'.currentOwner
        if ($currentOwner.email -match '(?i)(adm|admin|btg|svc|service)') {
            $resultMarkdown = "Well done. Azure DevOps organization owner should be a service account and not an individual.`n`n%TestResult%"
            $result = $true
        }
        else {
            $resultMarkdown = "Azure DevOps organization owner should not be an individual ($($currentOwner.name)). Note: This might be a false positive.`n`n%TestResult%"
            $result = $false
        }
        $markdown = "| Name | Id | E-mail |`n"
        $markdown += "| --- | --- | --- |`n"
        $markdown += "| $($currentOwner.name) | $($currentOwner.id) | $($currentOwner.email) |`n"
        $resultMarkdown = $resultMarkdown -replace '%TestResult%', $markdown
        Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'Critical'
    }
    return $result
}