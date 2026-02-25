<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the policy for additional security for your private feeds by limiting access to externally sourced packages when internally sourced packages are already present.
    This provides a new layer of security, which prevents malicious packages from a public registry being inadvertently consumed.
    These changes will not affect any package versions that are already in use or cached in your feed.

    https://devblogs.microsoft.com/devops/changes-to-azure-artifact-upstream-behavior

.EXAMPLE
    ```
    Test-AzdoArtifactsExternalPackageProtectionToken
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoArtifactsExternalPackageProtectionToken
#>

function Test-AzdoArtifactsExternalPackageProtectionToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.ArtifactsExternalPackageProtectionToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your Azure DevOps tenant limits access to externally sourced packages when internally sources packages are already present."
    } else {
        $resultMarkdown = "Your tenant should prefer to use internal source packages when present"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
