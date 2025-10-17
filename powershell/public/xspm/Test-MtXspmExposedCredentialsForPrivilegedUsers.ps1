<#
.SYNOPSIS
    Tests if exposed credentials for highly privileged users are present on vulnerable endpoints with high risk or exposure score.

.DESCRIPTION
    This function checks all credential artifacts exposed on vulnerable endpoints and correlates them with highly privileged users.

.OUTPUTS
    [bool] - Returns $true if no exposed credentials for highly privileged users are found on vulnerable endpoints, $false if any are found, $null if skipped or prerequisites not met.

.EXAMPLE
    Test-MtXspmExposedCredentialsForPrivilegedUsers

.LINK
    https://maester.dev/docs/commands/Test-MtXspmExposedCredentialsForPrivilegedUsers
#>

function Test-MtXspmExposedCredentialsForPrivilegedUsers {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple types of credentials and users.')]
    [OutputType([bool])]
    param()

    $UnifiedIdentityInfoExecutable = Get-MtXspmUnifiedIdentityInfo -ValidateRequiredTablesOnly
    if ( $UnifiedIdentityInfoExecutable -eq $false) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of MDA App Governance and MDI to get data for Defender XDR Advanced Hunting tables. Check https://maester.dev/docs/tests/MT.1080/#Prerequisites for more information.'
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
        $testResultMarkdown = "Well done. No authentication artifacts seems to be exposed on vulnerable endpoints."
    } else {
        $testResultMarkdown = "At least one authentication artifact seems to be exposed on a vulnerable endpoint.`n`n%TestResult%"

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
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
            Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity
        } else {
            Add-MtTestResultDetail -Result "No authentication artifacts of privileged users appear to be exposed on vulnerable endpoints. A total of $($userNotInScope.Count) other users (without Entra ID roles) have authentication artifacts on vulnerable devices."
        }
    }
    $result = [string]::IsNullOrEmpty($userInScope)
    return $result
}