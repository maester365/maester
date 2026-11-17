function Test-MtAdAuthNPolicyConfigCount {
    <#
    .SYNOPSIS
    Evaluates Active Directory Authentication Policy and Silo posture.
    .DESCRIPTION
    AD-CFG-08 reports policy and silo inventory and enforcement state. Authentication-expression
    attributes are optional, and LDAP omission alone does not establish why a value was not returned.
    .EXAMPLE
    Test-MtAdAuthNPolicyConfigCount
    .LINK
    https://maester.dev/docs/commands/Test-MtAdAuthNPolicyConfigCount
    .NOTES
    Original author: soulemike
    Authentication Policy and Silo posture rewrite: Mario Contestabile (rolling-code)
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
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Starting Test-MtAdAuthNPolicyConfigCount'
    $adState = Get-MtADDomainState -Categories @('AuthenticationPolicies')
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    if ($null -eq $adState['AuthenticationPolicyState']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Authentication Policy LDAP evidence is unavailable. Review verbose LDAP collection output and access to CN=AuthN Policy Configuration.'
        return $null
    }

    $state = $adState['AuthenticationPolicyState']
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Authentication Policies | $($state.PolicyCount) |`n"
    $result += "| Enforced Authentication Policies | $($state.EnforcedPolicyCount) |`n"
    $result += "| Authentication Policy Silos | $($state.SiloCount) |`n"
    $result += "| Enforced Authentication Policy Silos | $($state.EnforcedSiloCount) |`n"

    if ($state.PolicyCount -eq 0 -and $state.SiloCount -eq 0) {
        $summary = 'No Authentication Policy or Authentication Policy Silo objects were detected.'
    }
    elseif (@($state.NonEnforcedSilos).Count -gt 0) {
        $siloNames = @($state.NonEnforcedSilos | ForEach-Object { Get-MtSafeMarkdown -Text ([string]$_) }) -join ', '
        $summary = "Authentication Policy and Silo posture was collected successfully. Review non-enforced silos: $siloNames"
    }
    else {
        $summary = 'Authentication Policy and Silo posture was collected successfully.'
    }

    Add-MtTestResultDetail -Result "$summary`n`n$result"
    return $true
}
