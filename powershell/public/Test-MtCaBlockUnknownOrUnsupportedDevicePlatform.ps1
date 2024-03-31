<#
 .Synopsis
  Checks if the tenant has at least one Conditional Access policy is configured to block access for unknown or unsupported device platforms

 .Description
    Microsoft recommends blocking access for unknown or unsupported device platforms.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-policy-unknown-unsupported-device

 .Example
  Test-MtCaBlockUnknownOrUnsupportedDevicePlatform
#>

Function Test-MtCaBlockUnknownOrUnsupportedDevicePlatform {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $KnownPlatforms = @(
        "android",
        "iOS",
        "windows",
        "macOS",
        "linux",
        "windowsPhone"
    )

    $testDescription = "
Microsoft recommends blocking access for unknown or unsupported device platforms.

See [Block access for unknown or unsupported device platform - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-policy-unknown-unsupported-device)"
    $testResult = "These conditional access policies block access for unknown or unsupported device platforms:`n`n"

    $result = $false
    foreach ($policy in $policies) {
        try {
            # Check if all known platforms are excluded from the policy
            $AllKnownPlatformsExcluded = ( Compare-Object -ReferenceObject $KnownPlatforms -DifferenceObject $policy.conditions.platforms.excludePlatforms -IncludeEqual -ExcludeDifferent -PassThru | Measure-Object | Select-Object -ExpandProperty Count ) -eq $KnownPlatforms.Count
        } catch {
            $AllKnownPlatformsExcluded = $false
        }
        if ( $policy.grantcontrols.builtincontrols -eq 'block' `
                -and $policy.conditions.platforms.includePlatforms -eq "All" `
                -and $AllKnownPlatformsExcluded -ne $false `
        ) {
            $result = $true
            $currentresult = $true
            $testResult += "  - [$($policy.displayname)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    if ($result -eq $false) {
        $testResult = "There was no conditional access policy blocking access for unknown or unsupported device platforms."
    }
    Add-MtTestResultDetail -Description $testDescription -Result $testResult

    return $result
}