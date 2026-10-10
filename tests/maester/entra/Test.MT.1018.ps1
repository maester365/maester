function Test-MtCaEnforceSignInFrequency {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy enforcing sign-in frequency for non-corporate devices

    .Description
    Sign-in frequency Conditional Access policy can be helpful to minimize the risk of data leakage from a shared device.

    Learn more:
    https://aka.ms/CATemplatesBrowserSession

    .Example
    Test-MtCaEnforceSignInFrequency

    .LINK
    https://maester.dev/docs/commands/Test-MtCaEnforceSignInFrequency
    #>
    [MaesterTest(
        Id = 'MT.1018',
        Title = 'At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices.',
        Severity = 'Medium',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('CA', 'Maester'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'f-bader'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        # Ignore device filters for compliant devices.
        [switch]$AllDevices
    )

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }

    $testDescription = '
Microsoft recommends disabling browser persistence for users accessing the tenant from a unmanaged device.

See [Require reauthentication and disable browser persistence - Microsoft Learn](https://aka.ms/CATemplatesBrowserSession)'
    $testResult = "These Conditional Access policies enforce sign-in frequency:`n`n"

    $result = $false
    foreach ($policy in $policies) {
        # Check if device filter for compliant or hybrid Azure AD joined devices is present
        if (-not $AllDevices.IsPresent) {
            if ( $policy.conditions.devices.deviceFilter.mode -eq 'include' -and
                $policy.conditions.devices.deviceFilter.rule -match 'device.trustType -ne \"ServerAD\"' -and
                $policy.conditions.devices.deviceFilter.rule -match 'device.isCompliant -ne True'
            ) {
                $IsDeviceFilterPresent = $true
            } elseif ( $policy.conditions.devices.deviceFilter.mode -eq 'exclude' -and
                $policy.conditions.devices.deviceFilter.rule -match 'device.trustType -eq \"ServerAD\"' -and
                $policy.conditions.devices.deviceFilter.rule -match 'device.isCompliant -eq True'
            ) {
                $IsDeviceFilterPresent = $true
            } else {
                $IsDeviceFilterPresent = $false
            }
        } else {
            # We don't care about device filter if we are checking for all devices
            $IsDeviceFilterPresent = $true
        }
        if ( $policy.sessionControls.signInFrequency.isEnabled -eq $true -and
            $policy.sessionControls.signInFrequency.frequencyInterval -eq 'timeBased' -and
            $IsDeviceFilterPresent -and
            $policy.conditions.users.includeUsers -eq 'All' -and
            $policy.conditions.applications.includeApplications -eq 'All'
        ) {
            $result = $true
            $CurrentResult = $true
            $testResult += "  - [$(Get-MtSafeMarkdown $policy.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
        } else {
            $CurrentResult = $false
        }
        Write-Verbose "$($policy.displayName) - $CurrentResult"
    }

    if ($result -eq $false) {
        $testResult = 'There was no Conditional Access policy enforcing sign-in frequency for non-corporate devices.'
    }

    Add-MtTestResultDetail -Description $testDescription -Result $testResult
    return $result
}
