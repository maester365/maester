function Get-MtCisaPhishingResistantPolicy {
    <#
    .SYNOPSIS
    Returns Conditional Access policies that enforce phishing-resistant MFA for all users and applications.

    .DESCRIPTION
    Policies with exclusions are not counted because Maester has no matching SCuBA exclusion allowlists.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $phishingResistantMethods = @('windowsHelloForBusiness', 'fido2', 'x509CertificateMultiFactor')

    $policies = Get-MtConditionalAccessPolicy | Where-Object {
        $authenticationStrength = $_.grantControls.authenticationStrength
        $allowedCombinations = @($authenticationStrength.allowedCombinations | Where-Object { $_ })

        $_.state -eq 'enabled' -and
        $_.conditions.applications.includeApplications -contains 'All' -and
        $_.conditions.users.includeUsers -contains 'All' -and
        -not $_.conditions.users.excludeUsers -and
        -not $_.conditions.users.excludeGroups -and
        -not $_.conditions.users.excludeRoles -and
        -not $_.conditions.applications.excludeApplications -and
        $null -eq $_.conditions.users.excludeGuestsOrExternalUsers -and
        $authenticationStrength -and (
            $allowedCombinations.Count -gt 0 -and
            @($allowedCombinations | Where-Object { $_ -notin $phishingResistantMethods }).Count -eq 0
        )
    }

    return @($policies)
}
