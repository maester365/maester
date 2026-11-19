function Test-MtAdGpoTotalCount {
    <#
    .SYNOPSIS
    Inventories the total number of GPOs for investigation.
    .DESCRIPTION
    Counts cached GPO metadata. An inventory count is not a security verdict;
    missing collection is an error, not an empty successful inventory.
    #>
    [MaesterTest(
        Id = 'AD-GPO-01', Title = 'GPO inventory should be investigated',
        Product = 'ad', Feature = 'group-policy', Area = 'infrastructure',
        ResourceType = 'GroupPolicy', Severity = 'Info', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOs) { throw 'The GPO inventory could not be retrieved.' }
    $count = @($state.GPOs | Where-Object { $null -ne $_ }).Count
    $summary = if ($count -eq 0) { 'No GPOs were returned in the collected inventory.' } else { "The collected inventory contains $count GPOs. Review policy inventory and ownership." }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total GPOs' = $count })
    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
