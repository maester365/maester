function Test-AzdoAllowRequestAccessToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $UserPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User'
    $Policy = $UserPolicies.policy | where-object -property name -eq 'Policy.AllowRequestAccessToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "When enabled, this policy allows users to request access, triggering email notifications to administrators for review and approval."
    }
    else {
        $resultMarkdown = "Well done. Disabling the policy stops these requests and notifications."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Severity 'High'

    return $result
}
