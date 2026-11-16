function Get-MtCisaPhishingResistantPolicy {
    <#
    .SYNOPSIS
    Returns Conditional Access policies that enforce phishing-resistant MFA for all users and applications.

    .DESCRIPTION
    User and group exclusions are counted only when they match configured emergency access accounts or groups.
    Other exclusions are not counted because Maester has no matching SCuBA exclusion allowlists.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [object[]] $EmergencyAccessAccounts = @()
    )

    $phishingResistantMethods = @('windowsHelloForBusiness', 'fido2', 'x509CertificateMultiFactor')
    $emergencyAccessObjectIds = @(Get-MtEmergencyAccessAccount -Account $EmergencyAccessAccounts | ForEach-Object { $_.ObjectId })

    $policies = Get-MtConditionalAccessPolicy | Where-Object {
        $authenticationStrength = $_.grantControls.authenticationStrength
        $allowedCombinations = @($authenticationStrength.allowedCombinations | Where-Object { $_ })
        $userAndGroupExclusions = @(
            $_.conditions.users.excludeUsers
            $_.conditions.users.excludeGroups
        ) | Where-Object { $_ }
        $unapprovedExclusions = @($userAndGroupExclusions | Where-Object { $_ -notin $emergencyAccessObjectIds })

        $_.state -eq 'enabled' -and
        $_.conditions.applications.includeApplications -contains 'All' -and
        $_.conditions.users.includeUsers -contains 'All' -and
        $unapprovedExclusions.Count -eq 0 -and
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
