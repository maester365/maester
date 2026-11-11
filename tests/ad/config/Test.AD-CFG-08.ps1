function Test-MtAdAuthNPolicyConfigCount {
    <#
    .SYNOPSIS
    Evaluates Active Directory Authentication Policy and Silo posture.
    .DESCRIPTION
    AD-CFG-08 collects Authentication Policies and Silos directly from the configuration naming
    context, reports enforcement state, and distinguishes absent expression attributes from
    intentionally empty values.
    .EXAMPLE
    Test-MtAdAuthNPolicyConfigCount
    .LINK
    https://maester.dev/docs/commands/Test-MtAdAuthNPolicyConfigCount
    .NOTES
    Author: Mario Contestabile
    LinkedIn: https://www.linkedin.com/in/mario-contestabile/
    #>
    [MaesterTest(
        Id = 'AD-CFG-08',
        Title = 'Authentication Policy and Silo posture should be retrievable',
        Product = 'ad',
        Feature = 'directory-configuration',
        Area = 'authentication',
        ResourceType = 'Policy',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Configuration/*:ReadProperty'),
        # Maester requires the Author attribute to use the contributor's GitHub handle for catalog attribution.
        Author = 'rolling-code'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Starting Test-MtAdAuthNPolicyConfigCount'

    $adState = Get-MtADDomainState -Categories @('AuthenticationPolicies')
    if ($null -eq $adState -or $null -eq $adState['AuthenticationPolicyState']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Authentication Policy collection failed or returned no state. Review verbose LDAP collection output and access to CN=AuthN Policy Configuration.'
        return $null
    }

    # Get-MtADDomainState returns an OrderedDictionary, so use key access to preserve its public return contract.
    $state = $adState['AuthenticationPolicyState']
    # A successful empty collection is valid evidence and must not be presented as a failed LDAP query.
    $testResult = $true
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Authentication Policies | $($state.PolicyCount) |`n"
    $result += "| Enforced Authentication Policies | $($state.EnforcedPolicyCount) |`n"
    $result += "| Authentication Policy Silos | $($state.SiloCount) |`n"
    $result += "| Enforced Authentication Policy Silos | $($state.EnforcedSiloCount) |`n"
    $result += "| Requested expression attributes not returned | $($state.MissingRequiredAttributeCount) |`n"

    if ($state.PolicyCount -eq 0) {
        $summary = 'No Authentication Policy objects were detected. Expression-attribute evaluation is not applicable because no policy instances exist.'
    }
    elseif ($state.MissingRequiredAttributeCount -gt 0) {
        $summary = 'Authentication Policy objects were collected, but one or more optional expression attributes were not returned. Their configuration state is unknown; do not infer that they are unset or that collection was incomplete.'
    }
    else {
        $summary = 'Authentication Policy and Silo posture was collected successfully, including enforcement and expression-attribute availability.'
    }

    Add-MtTestResultDetail -Result "$summary`n`n$result"
    return $testResult
}