<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring multifactor authentication to access Azure management.

 .Description
    MFA for Azure management is a critical security control. This function checks if the tenant has at least one
    conditional access policy requiring multifactor authentication to access Azure management.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-azure-management

 .Example
  Test-MtCaMfaForAdminManagement

.LINK
    https://maester.dev/docs/commands/Test-MtCaMfaForAdminManagement
#>
function Test-MtCaMfaForAdminManagement {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }
        $policiesResult = New-Object System.Collections.ArrayList

        $testDescription = '
Microsoft recommends requiring MFA for Azure Management.

See [Require MFA for administrators - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-admin-mfa)'

        $result = $false
        foreach ($policy in $policies) {
            if (
                (
                    $policy.grantControls.builtInControls -contains 'mfa' -or
                    $policy.grantControls.authenticationStrength.requirementsSatisfied -contains 'mfa'
                ) -and
                (
                    $policy.conditions.users.includeUsers -eq 'All' -or
                    (
                        '62e90394-69f5-4237-9190-012177145e10' -in $policy.conditions.users.includeRoles -and
                        '194ae4cb-b126-40b2-bd5b-6091b380977d' -in $policy.conditions.users.includeRoles -and
                        'f28a1f50-f6e7-4571-818b-6a12f2af6b6c' -in $policy.conditions.users.includeRoles -and
                        '29232cdf-9323-42fd-ade2-1d097af3e4de' -in $policy.conditions.users.includeRoles -and
                        'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9' -in $policy.conditions.users.includeRoles -and
                        '729827e3-9c14-49f7-bb1b-9608f156bbb8' -in $policy.conditions.users.includeRoles -and
                        'b0f54661-2d74-4c50-afa3-1ec803f12efe' -in $policy.conditions.users.includeRoles -and
                        'fe930be7-5e62-47db-91af-98c3a49a38b1' -in $policy.conditions.users.includeRoles -and
                        'c4e39bd9-1100-46d3-8c65-fb160da0071f' -in $policy.conditions.users.includeRoles -and
                        '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3' -in $policy.conditions.users.includeRoles -and
                        '158c047a-c907-4556-b7ef-446551a6b5f7' -in $policy.conditions.users.includeRoles -and
                        '966707d0-3269-4727-9be2-8c3a10f19b9d' -in $policy.conditions.users.includeRoles -and
                        '7be44c8a-adaf-4e2a-84d6-ab2649e08a13' -in $policy.conditions.users.includeRoles -and
                        'e8611ab8-c189-46e8-94e1-60213ab1f814' -in $policy.conditions.users.includeRoles
                    )
                ) -and
                (
                    '797f4846-ba00-4fd7-ba43-dac1f8f63013' -in $policy.conditions.applications.includeApplications -or
                    'MicrosoftAdminPortals' -in $policy.conditions.applications.includeApplications -or
                    $policy.conditions.applications.includeApplications -contains 'All'
                )
            ) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( $result ) {
            $testResult = "The following conditional access policies require multi-factor authentication for azure management:`n`n%TestResult%"
        } else {
            $testResult = 'No conditional access policy requires multi-factor authentication for azure management resources.'
        }
        Add-MtTestResultDetail -Description $testDescription -GraphObjects $policiesResult -Result $testResult -GraphObjectType ConditionalAccess

        return $result
    } catch {
        Add-MtTestResultDetail -Description $testDescription -Error $_.Exception.Message
        return $false
    }
}
