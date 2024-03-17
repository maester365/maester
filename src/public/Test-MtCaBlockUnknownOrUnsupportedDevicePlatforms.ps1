<#
 .Synopsis
  Checks if the tenant has at least one Conditional Access policy is configured to block access for unknown or unsupported device platforms

 .Description
    Microsoft recommends blocking access for unknown or unsupported device platforms.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-policy-unknown-unsupported-device

 .Example
  Test-MtCaBlockUnknownOrUnsupportedDevicePlatforms
#>

Function Test-MtCaBlockUnknownOrUnsupportedDevicePlatforms {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Set-StrictMode -Off
    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }

    $KnownPlatforms = @(
        "android",
        "iOS",
        "windows",
        "macOS",
        "linux",
        "windowsPhone"
    )

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
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }
    Set-StrictMode -Version Latest

    return $result
}