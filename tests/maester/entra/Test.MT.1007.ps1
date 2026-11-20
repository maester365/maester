function Test-MtCaMfaForAllUsers {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy requiring multifactor authentication for all users

    .Description
    MFA for all users Conditional Access policy can be used to require MFA for all users in the tenant.

    A policy that a custom control alone satisfies doesn't count: custom controls don't satisfy the
    multifactor authentication requirement, and Microsoft deprecated them in favor of external MFA. A policy
    that requires MFA and a custom control (AND) still counts.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa
    https://learn.microsoft.com/entra/identity/conditional-access/how-to-migrate-custom-controls-external-mfa

    .Example
    Test-MtCaMfaForAllUsers

    .LINK
    https://maester.dev/docs/commands/Test-MtCaMfaForAllUsers
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'AllUsers is a well known term for Conditional Access policies.')]
    [MaesterTest(
        Id = 'MT.1007',
        Title = 'At least one Conditional Access policy is configured to require MFA for all users.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110'),
        Control = ('nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-2(2)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'f-bader',
        Contributor = ('brianreidc7', 'SamErde', 'julien-ly')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }
        # Remove policies that only require MFA in response to elevated risk (password change or risk
        # remediation grant control, or scoped via user/sign-in risk conditions), as those are conditional
        # on Identity Protection risk detections rather than requiring MFA on every sign-in.
        $policies = $policies | Where-Object {
            $_.grantControls.builtInControls -notcontains 'passwordChange' -and
            $_.grantControls.builtInControls -notcontains 'riskRemediation' -and
            -not $_.conditions.userRiskLevels -and
            -not $_.conditions.signInRiskLevels
        }
        $policiesResult = New-Object System.Collections.ArrayList
        # Policies that target all users and all resources and that a custom control alone satisfies. Custom
        # controls don't satisfy the multifactor authentication requirement, so these policies don't count.
        $customControlPolicies = New-Object System.Collections.ArrayList

        $result = $false
        foreach ($policy in $policies) {
            $hasCustomAuthenticationFactor = $false
            if ($null -ne $policy.grantControls -and $null -ne $policy.grantControls.customAuthenticationFactors) {
                $hasCustomAuthenticationFactor = @(
                    $policy.grantControls.customAuthenticationFactors |
                        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
                ).Count -gt 0
            }

            $targetsAllUsersAndResources = $policy.conditions.users.includeUsers -eq 'All' -and
                $policy.conditions.applications.includeApplications -eq 'All'
            # Unless the grant requires every control (AND), a custom control alone satisfies the policy.
            $customControlSatisfiesPolicy = $hasCustomAuthenticationFactor -and $policy.grantControls.operator -ne 'AND'

            if (
                (
                    $policy.grantControls.builtInControls -contains 'mfa' -or
                    $policy.grantControls.authenticationStrength.requirementsSatisfied -contains 'mfa'
                ) -and
                -not $customControlSatisfiesPolicy -and
                $targetsAllUsersAndResources
            ) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
                if ($customControlSatisfiesPolicy -and $targetsAllUsersAndResources) {
                    $customControlPolicies.Add($policy) | Out-Null
                }
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( $result ) {
            $testResult = "The following Conditional Access policies require multi-factor authentication for all users:`n`n%TestResult%"
        } else {
            $testResult = 'No Conditional Access policy requires multi-factor authentication for all users.'
        }

        if ($customControlPolicies.Count -gt 0) {
            $customControlList = ($customControlPolicies | ForEach-Object { "- $(Get-MtSafeMarkdown $_.displayName)" }) -join "`n"
            $migrationLink = 'https://learn.microsoft.com/entra/identity/conditional-access/how-to-migrate-custom-controls-external-mfa'
            $testResult += "`n`nThe following policies target all users, and a custom control alone satisfies them. A custom control " +
                "doesn't satisfy the multifactor authentication requirement, so they don't count. Custom controls are deprecated: " +
                "[migrate them to external MFA]($migrationLink).`n`n$customControlList"
        }

        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $false
    }
}
