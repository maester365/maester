function Test-MtXspmExposedCredentialsForPrivilegedUsersCompliance {
    <#
    .SYNOPSIS
    Tests if exposed credentials for highly privileged users are present on vulnerable endpoints with high risk or exposure score.

    .DESCRIPTION
    This function checks all credential artifacts exposed on vulnerable endpoints and correlates them with highly privileged users.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmExposedCredentialsForPrivilegedUsersCompliance
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
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    $UnifiedIdentityInfoExecutable = Get-MtXspmUnifiedIdentityInfo -ValidateRequiredTablesOnly
    if ( $UnifiedIdentityInfoExecutable -eq $false) {
            return $null
    }

    Write-Verbose "Get details from UnifiedIdentityInfo ..."
    $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo

    Write-Verbose "Get exposed credentials from XSPM by using ExposedAuthenticationArtifact query..."
    $ExposedAuthArtifacts = Get-MtXspmExposedAuthenticationArtifact

    # Filter for privileged users only
    $ExposedAuthArtifactsFromRiskyDevice = $ExposedAuthArtifacts | Where-Object {$_.RiskScore -eq "High" -or $_.ExposureScore -eq "High"}

    $Severity = "Medium"

    if ($return -or [string]::IsNullOrEmpty($ExposedAuthArtifactsFromRiskyDevice)) {
    } else {

        Write-Verbose "Found $($ExposedAuthArtifactsFromRiskyDevice.Count) exposed authentication artifacts from risky devices in total."

        $userInScope = @()
        $userNotInScope = @()
        $result = "| AccountName | Device | Classification | Criticality Level | Artifacts | ExposureScore | RiskScore |`n"
        $result += "| --- | --- | --- | --- | --- | --- | --- |`n"
        foreach ($ExposedUserAuthArtifact in $ExposedAuthArtifactsFromRiskyDevice) {
            $EnrichedUserDetails = $UnifiedIdentityInfo | Where-Object { $_.AccountObjectId -eq $ExposedUserAuthArtifact.AccountObjectId } | Select-Object Classification, AccountObjectId, CriticalityLevel, AccountDisplayName, TenantId
            if ($EnrichedUserDetails.Classification -eq "ControlPlane" -or $EnrichedUserDetails.Classification -eq "ManagementPlane" -or $EnrichedUserDetails.CriticalityLevel -lt "1") {
                $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $EnrichedUserDetails.Classification

                if($EnrichedUserDetails.Classification -eq "ControlPlane") {
                    $Severity = "High"
                }

                $UserLink = "[$($EnrichedUserDetails.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($EnrichedUserDetails.AccountObjectId))"
                $DeviceLink = "[$($ExposedUserAuthArtifact.Device)](https://security.microsoft.com/machines/v2/$($ExposedUserAuthArtifact.DeviceId)?tid=$($EnrichedUserDetails.TenantId))"
                foreach ($ExposedTokenArtifact in $ExposedUserAuthArtifact.TokenArtifacts) {
                    $UserArtifactItem = (Get-MtXspmAuthenticationArtifactIcon -ArtifactType $ExposedTokenArtifact) + " " + ((($ExposedTokenArtifact -csplit '(?=[A-Z])') -ne '') -join ' ') | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
                    $result += "| $($AdminTierLevelIcon) $($UserLink)  | $($DeviceLink) | $($EnrichedUserDetails.Classification) | $($EnrichedUserDetails.CriticalityLevel) | $($UserArtifactItem) | $($ExposedUserAuthArtifact.ExposureScore) | $($ExposedUserAuthArtifact.RiskScore) |`n"
                }
                $userInScope += $EnrichedUserDetails.AccountObjectId
            } else {
                $userNotInScope += $EnrichedUserDetails.AccountObjectId
            }
        }
        if ($userInScope.Count -gt 0) {
        } else {
        }
    }
    $result = [string]::IsNullOrEmpty($userInScope)
    return $result

}
