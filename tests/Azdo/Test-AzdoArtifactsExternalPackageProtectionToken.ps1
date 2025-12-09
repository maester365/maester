function Test-AzdoArtifactsExternalPackageProtectionToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.ArtifactsExternalPackageProtectionToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your Azure DevOps tenant limits access to externally sourced packages when internally sources packages are already present."
    }
    else {
        $resultMarkdown = "Your tenant should prefer to use internal source packages when present"
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
