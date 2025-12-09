function Test-AzdoAllowTeamAdminsInvitationsAccessToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User'
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.AllowTeamAdminsInvitationsAccessToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Team and project administrators is allowed to invite new users"
    }
    else {
        $resultMarkdown = "Well done. Enrolling to your Azure DevOps organization should be a controlled process."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Severity 'High'

    return $result
}
