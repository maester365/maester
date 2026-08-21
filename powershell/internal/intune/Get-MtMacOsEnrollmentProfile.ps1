function Get-MtMacOsEnrollmentProfile {
    <#
    .SYNOPSIS
    Retrieves macOS Automated Device Enrollment (ADE) profiles across all Apple enrollment tokens.

    .DESCRIPTION
    macOS enrollment profiles are not returned by a single flat endpoint. They hang off each Apple
    Business Manager / Automated Device Enrollment token, so retrieval is a two-hop query:
    deviceManagement/depOnboardingSettings gives the tokens, then enrollmentProfiles under each token
    gives the profiles.

    This helper performs both hops and returns a normalized object per macOS profile, carrying the
    local account and password-rotation configuration that macOS LAPS depends on.

    The adminAccountPassword property returned by Graph is deliberately never surfaced. Only whether
    an admin account name is configured is retained, so that no seeded credential can reach a
    Maester report.

    .EXAMPLE
    Get-MtMacOsEnrollmentProfile

    Returns the macOS ADE enrollment profiles configured in the tenant.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param()

    $result = [System.Collections.Generic.List[pscustomobject]]::new()

    $tokens = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/depOnboardingSettings' -ApiVersion beta)
    if ($tokens.Count -eq 0) {
        Write-Verbose "No Apple enrollment (depOnboardingSettings) tokens found."
        return $result
    }

    foreach ($token in $tokens) {
        $profiles = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/depOnboardingSettings/$($token.id)/enrollmentProfiles" -ApiVersion beta)
        $macOsProfiles = @($profiles | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.depMacOSEnrollmentProfile' })

        foreach ($enrollmentProfile in $macOsProfiles) {
            $rotation = $enrollmentProfile.depProfileAdminAccountPasswordRotationSetting

            $result.Add([pscustomobject]@{
                    Id                        = $enrollmentProfile.id
                    Name                      = $enrollmentProfile.displayName
                    TokenName                 = $token.tokenName
                    IsDefault                 = ($enrollmentProfile.isDefault -eq $true)
                    # Presence only. The password value itself is never retained.
                    HasAdminAccount           = -not [string]::IsNullOrWhiteSpace($enrollmentProfile.adminAccountUserName)
                    HideAdminAccount          = ($enrollmentProfile.hideAdminAccount -eq $true)
                    HasPasswordRotation       = ($null -ne $rotation)
                    AutoRotationPeriodInDays  = $rotation.autoRotationPeriodInDays
                    RotateOnRetrieval         = ($rotation.depProfileDelayAutoRotationSetting.onRetrievalAutoRotatePasswordEnabled -eq $true)
                    AwaitFinalConfiguration   = ($enrollmentProfile.waitForDeviceConfiguredConfirmation -eq $true)
                    UsePlatformSsoAtSetup     = ($enrollmentProfile.usePlatformSSODuringSetupAssistant -eq $true)
                })
        }
    }

    return $result
}
