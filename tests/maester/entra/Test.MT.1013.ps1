function Test-MtCaRequirePasswordChangeForHighUserRisk {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy requiring password change for high user risk.

    .Description
    Password change for high user risk is a good way to prevent compromised accounts from being used to access your tenant.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk-user

    .Example
    Test-MtCaRequirePasswordChangeForHighUserRisk

    .LINK
    https://maester.dev/docs/commands/Test-MtCaRequirePasswordChangeForHighUserRisk
    #>
    [MaesterTest(
        Id = 'MT.1013',
        Title = 'At least one Conditional Access policy is configured to require new password when user risk is high.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('CA', 'Maester'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Author = 'f-bader'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }
    # Only check policies that have password change as a grant control
    $policies = $policies | Where-Object { $_.grantControls.builtInControls -contains 'passwordChange' }
    $policiesResult = New-Object System.Collections.ArrayList

    $result = $false
    foreach ($policy in $policies) {
        if (
            $policy.grantControls.builtInControls -contains 'passwordChange' -and
            $policy.conditions.users.includeUsers -eq 'All' -and
            $policy.conditions.applications.includeApplications -eq 'All' -and
            'high' -in $policy.conditions.userRiskLevels
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
        $testResult = "The following Conditional Access policies require password change for risky users`n`n%TestResult%"
    } else {
        $testResult = 'No Conditional Access policy requires a password change for risky users.'
    }
    Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

    return $result
}
