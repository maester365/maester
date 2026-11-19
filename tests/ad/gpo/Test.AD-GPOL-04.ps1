function Test-MtAdGpoEnforcedCount {
    <#
    .SYNOPSIS
    Checks that GPO links are not enforced.
    .DESCRIPTION
    Passes when no enforced link entries exist, fails when any exist. Enforcement
    overrides Block Inheritance; review intentional enforcement before changing it.
    #>
    [MaesterTest(
        Id = 'AD-GPOL-04', Title = 'GPO links should not use enforcement',
        Product = 'ad', Feature = 'group-policy', Area = 'infrastructure',
        ResourceType = 'GroupPolicy', Severity = 'Low', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOLinks) { throw 'GPO links could not be collected; enforcement cannot be assessed.' }
    $links = @($state.GPOLinks | Where-Object { $null -ne $_ })
    if (@($links | Where-Object { $null -eq $_.IsEnforced }).Count -gt 0) { throw 'One or more GPO link enforcement states are unknown.' }
    $enforced = @($links | Where-Object { $true -eq $_.IsEnforced } | Sort-Object DistinguishedName, GpoGuid)
    $pass = $enforced.Count -eq 0
    $summary = if ($pass) { 'Well done. No enforced GPO links were found.' } else { "$($enforced.Count) of $($links.Count) GPO links are enforced. Review intentional overrides of Block Inheritance and remove unnecessary enforcement." }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total GPO links' = $links.Count; 'Enforced GPO links' = $enforced.Count }) -Details $enforced -Properties GpoGuid, DistinguishedName -Headers 'GPO Id', 'Linked container'
    Add-MtTestResultDetail -Result $result
    return $pass
}
