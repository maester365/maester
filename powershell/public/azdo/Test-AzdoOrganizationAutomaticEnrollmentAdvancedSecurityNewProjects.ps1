function Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProjects {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationAdvancedSecurity).enableOnCreate

    if ($result) {
        $resultMarkdown = "Well done. New projects will by default have Advanced Security enabled."
    }
    else {
        $resultMarkdown = "New projects must be manually enrolled in Advanced Security."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
