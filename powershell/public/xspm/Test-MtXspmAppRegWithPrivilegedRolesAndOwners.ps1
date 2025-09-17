<#
.SYNOPSIS
    Tests if app registration owners with highly privileged Entra ID roles have delegated ownership.

.DESCRIPTION
    This function checks all Entra ID app registrations with highly privileged Entra ID roles and checks if ownership has been delegated.

.OUTPUTS
    [bool] - Returns $true if no owners on app registrations with highly privileged Entra ID roles, $false if any owners have been assigned, $null if skipped or prerequisites not met.

.EXAMPLE
    Test-MtXspmAppRegWithPrivilegedRolesAndOwners

.LINK
    https://maester.dev/docs/commands/Test-MtXspmAppRegWithPrivilegedRolesAndOwners
#>

function Test-MtXspmAppRegWithPrivilegedRolesAndOwners {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks for multiple owners for each application object.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Setting severity variable will set dynamic based on findings')]
    [OutputType([bool])]
    param()

    $UnifiedIdentityInfoExecutable = Get-MtXspmUnifiedIdentityInfo -ValidateRequiredTablesOnly
    if ( $UnifiedIdentityInfoExecutable -eq $false) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of MDA App Governance and MDI to get data for Defender XDR Advanced Hunting tables. Check https://maester.dev/docs/tests/MT.1078/#Prerequisites for more information.'
            return $null
    }

    try {
        Write-Verbose "Get details from UnifiedIdentityInfo ..."
        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    $HighPrivilegedAppsByEntraRoles = $UnifiedIdentityInfo | where-object {$_.AssignedEntraRoles.Classification -eq "ControlPlane" -or $_.AssignedEntraRoles.Classification -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True }
    $SensitiveDirectoryRolesOnAppsWithOwners = $HighPrivilegedAppsByEntraRoles | Where-Object { $null -ne $_.OwnedBy -and $_.Type -eq "Workload" }

    if ($return -or [string]::IsNullOrEmpty($SensitiveDirectoryRolesOnAppsWithOwners)) {
        $testResultMarkdown = "Well done. No application and workload identity has a privileged directory role with an owner."
    } else {
        $testResultMarkdown = "At least one application has ownership with a risk of sensitive directory role.`n`n%TestResult%"

        $result = "| ApplicationName | Ownership | Tier Breach | Sensitive Directory Role |`n"
        $result += "| --- | --- | --- | --- |`n"

        Write-Verbose "Found $($SensitiveDirectoryRolesOnAppsWithOwners.Count) app registrations with directory role assigned to owner."

        foreach ($SensitiveApp in $SensitiveDirectoryRolesOnAppsWithOwners) {
            $filteredApiPermissions = $SensitiveApp.AssignedEntraRoles | where-object {$_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.RoleIsPrivileged -eq $True } | Select-Object RoleDefinitionName, Classification
            # XSPM supports only Directory scope for now
            $filteredApiPermissions | Add-Member -MemberType NoteProperty -Name RoleScope -Value "Directory" -Force
            $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $filteredApiPermissions.Classification
            $SensitiveApp.OwnedBy | ForEach-Object {
                $Owner = $_
                $XspmIdentifiers = ($Owner.EntityIds | Where-Object {$_.type -eq "AadObjectId"}).id
                if ($XspmIdentifiers -match 'objectid=([0-9a-fA-F\-]{36})') {
                    $MatchedObjectId = $matches[1]
                    $MatchedOwner = $UnifiedIdentityInfo | Where-Object {$_.AccountObjectId -eq $MatchedObjectId}
                    $OwnerAdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $MatchedOwner.Classification
                    if ($MatchedOwner.Type -eq "Workload") {
                        $OwnerLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($MatchedOwner.AccountObjectId)/appId/$($MatchedOwner.AppId))"
                    } else {
                        $OwnerLink = "[$($MatchedOwner.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($MatchedOwner.AccountObjectId))"
                    }
                    $Owner = "$($OwnerAdminTierLevelIcon) $OwnerLink"
                    $TierBreach = $MatchedOwner.Classification -ne "ControlPlane" -and $MatchedOwner.Classification -ne "$filteredApiPermissions.Classification"
                } else {
                    $Owner = $($_.NodeName) - $($_.NodeLabel)
                    $TierBreach = "Unknown"
                }

                # Increase severity to high if tier breach detected
                if ($TierBreach -eq $true) {
                    $Severity = "High"
                } else {
                    $Severity = "Medium"
                }

                # Summary of App roles in one column (as workaround for missing support of simple linebreak in one call)
                $DirectoryRolesSummary = $filteredApiPermissions | Select-Object -Unique RoleScope | ForEach-Object {
                    $RoleScope = $_.RoleScope
                    $DirectoryRoles = $filteredApiPermissions | Where-Object {$_.RoleScope -eq $RoleScope} | Select-Object RoleDefinitionName
                    "Scope $($RoleScope)" + ": " + "$($DirectoryRoles| ForEach-Object { '`' + $_.RoleDefinitionName + '`' })"
                }


                $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($SensitiveApp.AccountObjectId)/appId/$($SensitiveApp.AppId))"
                $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($Owner) | $($TierBreach) | $($DirectoryRolesSummary) |`n"
            }
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity
    $result = [string]::IsNullOrEmpty($SensitiveDirectoryRolesOnAppsWithOwners)
    return $result
}