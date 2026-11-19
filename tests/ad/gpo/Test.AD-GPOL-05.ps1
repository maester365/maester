function Test-MtAdGpoBlockedInheritanceCount {
    <#
    .SYNOPSIS
    Checks that OUs do not block GPO inheritance.
    .DESCRIPTION
    Fails when gpOptions equals 1 on an OU. An unset gpOptions attribute uses the
    default (inheritance enabled); failed container collection is not a clean pass.
    #>
    [MaesterTest(
        Id = 'AD-GPOL-05', Title = 'OUs should not block Group Policy inheritance',
        Product = 'ad', Feature = 'group-policy', Area = 'infrastructure',
        ResourceType = 'OrganizationalUnit', Severity = 'Medium', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.LinkContainers) { throw 'GPO link containers could not be collected; inheritance blocking cannot be assessed.' }
    $ous = @($state.LinkContainers | Where-Object { @($_.ObjectClass) -contains 'organizationalUnit' })
    $blocked = @($ous | Where-Object { $null -ne $_.GpOptions -and [int]$_.GpOptions -eq 1 } | Sort-Object DistinguishedName)
    $pass = $blocked.Count -eq 0
    $summary = if ($pass) { 'Well done. No collected OU blocks Group Policy inheritance.' } else { "$($blocked.Count) of $($ous.Count) OUs block Group Policy inheritance. Review and justify these exceptions; enforced parent links still apply." }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total OUs' = $ous.Count; 'OUs blocking inheritance' = $blocked.Count }) -Details $blocked -Properties DistinguishedName -Headers OU
    Add-MtTestResultDetail -Result $result
    return $pass
}
