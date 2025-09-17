<#
.SYNOPSIS
    Tests if app registration have assigned privileged API permissions which are unused.

.DESCRIPTION
    This function checks all Entra ID app registrations with privileged API permissions and checks if any of them are unused.

.OUTPUTS
    [bool] - Returns $true if no owners on app registrations with privileged API permissions, $false if any owners have been assigned, $null if skipped or prerequisites not met.

.EXAMPLE
    Test-MtXspmAppRegWithPrivilegedUnusedPermissions

.LINK
    https://maester.dev/docs/commands/Test-MtXspmAppRegWithPrivilegedUnusedPermissions
#>

function Test-MtXspmAppRegWithPrivilegedUnusedPermissions {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks for multiple permissions.')]
    [OutputType([bool])]
    param()

    $UnifiedIdentityInfoExecutable = Get-MtXspmUnifiedIdentityInfo -ValidateRequiredTablesOnly
    if ( $UnifiedIdentityInfoExecutable -eq $false) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of MDA App Governance and MDI to get data for Defender XDR Advanced Hunting tables. Check https://maester.dev/docs/tests/MT.1079/#Prerequisites for more information.'
            return $null
    }

    try {
        Write-Verbose "Get details from UnifiedIdentityInfo ..."
        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    $Severity = "Medium"
    $HighPrivilegedAppsByApiPermissions = $UnifiedIdentityInfo | where-object {$_.ApiPermissions.Classification -eq "ControlPlane" -or $_.ApiPermissions.Classification -eq "ManagementPlane" -or $_.ApiPermissions.PrivilegeLevel -eq "High" }
    $SensitiveAppsWithUnusedPermissions = $HighPrivilegedAppsByApiPermissions | Where-Object { $_.ApiPermissions.InUse -eq $false }

    if ($return -or [string]::IsNullOrEmpty($SensitiveAppsWithUnusedPermissions)) {
        $testResultMarkdown = "Well done. No application and workload identity has a privileged API permission which are unused"
    } else {
        $testResultMarkdown = "At least one application has unused sensitive API permissions.`n`n%TestResult%"

        $result = "| ApplicationName | Enterprise Access Level | Sensitive App Role | API Provider |`n"
        $result += "| --- | --- | --- | --- | `n"

        Write-Verbose "Found $($SensitiveAppsWithUnusedPermissions.Count) app registrations with unused sensitive API permissions."

        foreach ($SensitiveApp in $SensitiveAppsWithUnusedPermissions) {
            $filteredApiPermissions = $SensitiveApp.ApiPermissions | Where-Object { ($_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.PrivilegeLevel -eq "High") -and $_.InUse -eq $false } | Select-Object AppDisplayName, AppRoleDisplayName, Classification | sort-object Classification, AppDisplayName
            if($filteredApiPermissions) {
                foreach ($filteredApiPermission in $filteredApiPermissions) {
                    if ($filteredApiPermission.Classification -eq "") { $filteredApiPermission.Classification = "Unknown" }
                    $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($SensitiveApp.AccountObjectId)/appId/$($SensitiveApp.AppId))"
                    $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $SensitiveApp.Classification
                    $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($filteredApiPermission.Classification) | $($filteredApiPermission.AppRoleDisplayName) | $($filteredApiPermission.AppDisplayName) |`n"
                }
            }
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity
    $result = [string]::IsNullOrEmpty($SensitiveAppsWithUnusedPermissions)
    return $result
}