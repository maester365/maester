function Test-AzdoArtifactsExternalPackageProtectionTokenCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the policy for additional security for your private feeds by limiting access to externally sourced packages when internally sourced packages are already present.
    This provides a new layer of security, which prevents malicious packages from a public registry being inadvertently consumed.
    These changes will not affect any package versions that are already in use or cached in your feed.

    https://devblogs.microsoft.com/devops/changes-to-azure-artifact-upstream-behavior
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoArtifactsExternalPackageProtectionTokenCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Running Test-AzdoArtifactsExternalPackageProtectionToken"


    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.ArtifactsExternalPackageProtectionToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your Azure DevOps tenant limits access to externally sourced packages when internally sourced packages are already present."
    } else {
        $resultMarkdown = "Your tenant should prefer to use internal source packages when present"
    }


    return $result

}
