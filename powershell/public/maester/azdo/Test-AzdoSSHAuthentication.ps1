function Test-AzdoSSHAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection'
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowSecureShell'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant allows developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    }
    else {
        $resultMarkdown = "Well done. Your tenant do not allow developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}