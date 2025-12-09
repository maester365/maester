function Test-AzdoFeedbackCollection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Privacy'
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.AllowFeedbackCollection'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your Azure DevOps tenant allows feedback collection."
    }
    else {
        $resultMarkdown = "You should have confidence that we're handling your data appropriately and for legitimate uses. Part of that assurance involves carefully restricting usage."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'Info'

    return $result
}
