# The DISA STIG checks, the tests their shims run with DISA's values, and the Entra helpers they read through. Graph is mocked.

BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue }

Describe 'DISA STIG checks' {
    It 'The idle session timeout passes at 15 minutes and fails at an hour or when none is set' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            $policy = { param($value) @([pscustomobject]@{ displayName = 'Timeout'; definition = @("{`"ActivityBasedTimeoutPolicy`":{`"Version`":1,`"ApplicationPolicies`":[{`"ApplicationId`":`"default`",`"WebSessionIdleTimeout`":`"$value`"}]}}") }) }
            Mock Invoke-MtGraphRequest { & $policy '00:15:00' } -ParameterFilter { $RelativeUri -eq 'policies/activityBasedTimeoutPolicies' }
            Test-MtDisaIdleSessionTimeout | Should -BeTrue
            Test-MtDisaEntraIdleSessionTimeout | Should -BeTrue
            Mock Invoke-MtGraphRequest { & $policy '01:00:00' } -ParameterFilter { $RelativeUri -eq 'policies/activityBasedTimeoutPolicies' }
            Test-MtDisaIntuneDesktopIdleSessionTimeout | Should -BeFalse
            Test-MtDisaIdleSessionTimeout -MaximumIdleTimeoutMinutes 60 | Should -BeTrue
            Mock Invoke-MtGraphRequest { @() } -ParameterFilter { $RelativeUri -eq 'policies/activityBasedTimeoutPolicies' }
            Test-MtDisaIdleSessionTimeout | Should -BeFalse
        }
    }

    It 'The lockout shims need a threshold of 3 and a duration of 900 seconds, and CIS 5.2.3.8 still ignores the duration' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            $settings = { param($threshold, $duration) @([pscustomobject]@{ templateId = '5cf42378-d67d-4f36-ba46-e8b86229381d'; values = @(
                            [pscustomobject]@{ name = 'LockoutThreshold'; value = $threshold }
                            [pscustomobject]@{ name = 'LockoutDurationInSeconds'; value = $duration }
                        ) }) }
            Mock Invoke-MtGraphRequest { & $settings '3' '900' }
            Test-MtDisaEntraLockout | Should -BeTrue
            Test-MtDisaIntuneDesktopLockout | Should -BeTrue
            Mock Invoke-MtGraphRequest { & $settings '3' '60' }
            Test-MtDisaEntraLockout | Should -BeFalse
            Test-MtCisSmartLockoutThreshold | Should -BeTrue
            Mock Invoke-MtGraphRequest { & $settings '5' '900' }
            Test-MtDisaEntraLockout | Should -BeFalse
            Mock Invoke-MtGraphRequest { @() }
            Test-MtDisaEntraLockout | Should -BeFalse -Because 'the defaults are 10 attempts and 60 seconds'
        }
    }

    It 'The device wipe approval shim needs a deviceWipe or deviceAction policy, and MT.1096 accepts any policy' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            Mock Invoke-MtGraphRequest { @([pscustomobject]@{ displayName = 'Scripts'; policyType = 'script' }) }
            Test-MtOperationApprovalPolicies | Should -BeTrue
            Test-MtDisaIntuneWipeApproval | Should -BeFalse
            Mock Invoke-MtGraphRequest { @([pscustomobject]@{ displayName = 'Wipe'; policyType = 'deviceWipe' }) }
            Test-MtDisaIntuneWipeApproval | Should -BeTrue
            Mock Invoke-MtGraphRequest { @([pscustomobject]@{ displayName = 'Actions'; policyType = 'unknown'; policySet = [pscustomobject]@{ policyType = 'deviceAction' } }) }
            Test-MtDisaIntuneWipeApproval | Should -BeTrue
            Mock Invoke-MtGraphRequest { @() }
            Test-MtOperationApprovalPolicies | Should -BeFalse
        }
    }

    It 'The log export shim asks for DISA''s eight categories, where CISA 4.1 asks for more' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            $disa = 'SignInLogs', 'AuditLogs', 'ServicePrincipalSignInLogs', 'ManagedIdentitySignInLogs', 'UserRiskEvents', 'RiskyUsers', 'RiskyServicePrincipals', 'ServicePrincipalRiskEvents'
            $all = $disa + 'NonInteractiveUserSignInLogs', 'MicrosoftGraphActivityLogs'
            Mock Invoke-AzRestMethod {
                if ($Path -like '*diagnosticSettingsCategories*') {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($all | ForEach-Object { @{ name = $_; properties = @{ categoryType = 'Logs' } } }) } | ConvertTo-Json -Depth 5) }
                } else {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = 'sentinel'; properties = @{ logs = @($disa | ForEach-Object { @{ category = $_; enabled = $true } }) } }) } | ConvertTo-Json -Depth 6) }
                }
            }
            Test-MtDisaEntraLogExport | Should -BeTrue
            Test-MtCisaDiagnosticSettings | Should -BeFalse
        }
    }

    It 'The sign-in banner passes with the full or the short banner and fails without branding' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            Mock Invoke-MtGraphRequest { @([pscustomobject]@{ id = 'org1' }) } -ParameterFilter { $RelativeUri -eq 'organization' }
            Mock Invoke-MtGraphRequest { [pscustomobject]@{ signInPageText = "You are accessing a U.S. Government (USG)   Information System (IS) that is provided`nfor USG-authorized use only. By using this IS..." } } -ParameterFilter { $RelativeUri -eq 'organization/org1/branding' }
            Test-MtDisaSignInBanner | Should -BeTrue
            Mock Invoke-MtGraphRequest { [pscustomobject]@{ signInPageText = "I've read & consent to terms in IS user agreem't." } } -ParameterFilter { $RelativeUri -eq 'organization/org1/branding' }
            Test-MtDisaSignInBanner | Should -BeTrue
            Mock Invoke-MtGraphRequest { [pscustomobject]@{ signInPageText = 'Welcome to Contoso' } } -ParameterFilter { $RelativeUri -eq 'organization/org1/branding' }
            Test-MtDisaSignInBanner | Should -BeFalse
            Test-MtDisaSignInBanner -AcceptedBannerTexts 'welcome to CONTOSO' | Should -BeTrue
            Mock Invoke-MtGraphRequest { throw 'Response status code does not indicate success: NotFound (Not Found).' } -ParameterFilter { $RelativeUri -eq 'organization/org1/branding' }
            Test-MtDisaSignInBanner | Should -BeFalse
        }
    }

    It 'The password lifetime fails a domain that never expires or exceeds the maximum, and asks for review when none is stored' {
        InModuleScope Maester {
            $script:details = @()
            Mock Add-MtTestResultDetail { $script:details += [pscustomobject]@{ Investigate = [bool]$Investigate } }
            $domain = { param($id, $days, $type = 'Managed', $verified = $true) [pscustomobject]@{ id = $id; authenticationType = $type; isVerified = $verified; passwordValidityPeriodInDays = $days } }
            Mock Invoke-MtGraphRequest { @((& $domain 'a.mil' 90), (& $domain 'fed.mil' 2147483647 'Federated')) }
            Test-MtDisaPasswordLifetime | Should -BeTrue
            Test-MtDisaIntuneDesktopPasswordLifetime | Should -BeFalse -Because 'the Intune STIG allows 60 days'
            Test-MtCisPasswordExpiry | Should -BeFalse -Because 'CIS asks that passwords never expire'
            Mock Invoke-MtGraphRequest { @((& $domain 'a.mil' 2147483647)) }
            Test-MtDisaPasswordLifetime | Should -BeFalse
            Test-MtCisPasswordExpiry | Should -BeTrue
            $script:details = @()
            Mock Invoke-MtGraphRequest { @((& $domain 'a.mil' $null)) }
            Test-MtDisaPasswordLifetime | Should -BeTrue
            $script:details[-1].Investigate | Should -BeTrue
            Test-MtCisPasswordExpiry | Should -BeTrue
        }
    }

    It 'The role activation alert fails a role with no additional recipient, or without a required one' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            Mock Get-MtDirectoryRoleAssignment { [pscustomobject]@{ Assignments = @(
                        [pscustomobject]@{ roleDefinitionId = 'r1'; AssignmentType = 'Active' }
                        [pscustomobject]@{ roleDefinitionId = 'r2'; AssignmentType = 'Eligible' }
                    ); EligibleChecked = $true } }
            Mock Invoke-MtGraphRequest { @([pscustomobject]@{ id = 'r1'; displayName = 'Role one' }, [pscustomobject]@{ id = 'r2'; displayName = 'Role two' }) } -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleDefinitions' }
            $policy = { param($recipients) [pscustomobject]@{ policy = [pscustomobject]@{ rules = @([pscustomobject]@{ id = 'Notification_Admin_EndUser_Assignment'; notificationRecipients = $recipients }) } } }
            Mock Invoke-MtGraphRequest { & $policy @('isso@contoso.mil', 'sa@contoso.mil') } -ParameterFilter { $RelativeUri -eq 'policies/roleManagementPolicyAssignments' }
            Test-MtDisaRoleActivationNotification | Should -BeTrue
            Test-MtDisaRoleActivationNotification -RequiredRecipients 'sa@contoso.mil', 'isso@contoso.mil' | Should -BeTrue
            Test-MtDisaRoleActivationNotification -RequiredRecipients 'soc@contoso.mil' | Should -BeFalse
            Mock Invoke-MtGraphRequest { & $policy @() } -ParameterFilter { $RelativeUri -eq 'policies/roleManagementPolicyAssignments' }
            Test-MtDisaRoleActivationNotification | Should -BeFalse
            Get-MtRoleActivationNotificationRecipient -RoleDefinitionId 'r1' | Should -BeNullOrEmpty
        }
    }

    It 'Inactive accounts follow the interactive sign-in and the creation date of accounts that never signed in' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            $now = [datetime]::UtcNow
            $user = { param($upn, $lastSignIn, $nonInteractive, $created) [pscustomobject]@{ id = $upn; userPrincipalName = $upn; userType = 'Member'; accountEnabled = $true; createdDateTime = $created.ToString('o'); signInActivity = [pscustomobject]@{ lastSignInDateTime = $lastSignIn; lastNonInteractiveSignInDateTime = $nonInteractive } } }
            Mock Invoke-MtGraphRequest { @((& $user 'a@contoso.mil' $now.AddDays(-5).ToString('o') $null $now.AddDays(-400)), (& $user 'new@contoso.mil' $null $null $now.AddDays(-2))) }
            Test-MtDisaInactiveAccount | Should -BeTrue
            Mock Invoke-MtGraphRequest { @((& $user 'b@contoso.mil' $now.AddDays(-40).ToString('o') $now.AddDays(-1).ToString('o') $now.AddDays(-400))) }
            Test-MtDisaInactiveAccount | Should -BeFalse -Because 'the STIG audit reads the interactive sign-in only'
            Test-MtDisaIntuneDesktopInactiveAccount -MaximumInactiveDays 45 | Should -BeTrue
            Mock Invoke-MtGraphRequest { @((& $user 'c@contoso.mil' $null $null $now.AddDays(-100))) }
            Test-MtDisaInactiveAccount | Should -BeFalse
        }
    }

    It 'Get-MtUserLastSignIn returns the latest sign-in in UTC, or nothing' {
        InModuleScope Maester {
            $u = [pscustomobject]@{ signInActivity = [pscustomobject]@{ lastSignInDateTime = '2026-01-01T00:00:00Z'; lastNonInteractiveSignInDateTime = '2026-02-01T00:00:00Z' } }
            (Get-MtUserLastSignIn -User $u).Month | Should -Be 2
            (Get-MtUserLastSignIn -User $u -InteractiveOnly).Month | Should -Be 1
            Get-MtUserLastSignIn -User ([pscustomobject]@{ signInActivity = $null }) | Should -BeNullOrEmpty
        }
    }
}
