function Test-MtAdMachineAccountQuota {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    .EXAMPLE
    Invoke-MtTest -Id AD-DOM-02
    Assess whether the connected domain machine account quota is zero.
    .LINK
    https://maester.dev/docs/tests/AD-DOM-02
    #>
    [MaesterTest(
        Id = 'AD-DOM-02',
        Title = 'Machine account quota is zero',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1136.002',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS.ms-DS-MachineAccountQuota:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Domain')
    if (-not $state.Domain -or $null -eq $state.Domain.MsDsMachineAccountQuota) { throw 'Machine account quota was not collected; the documented default of 10 cannot be substituted for missing data.' }
    $quota = [int]$state.Domain.MsDsMachineAccountQuota
    $ok = $quota -eq 0
    $metrics = Format-MtAdSummaryTable -Values ([ordered]@{
        'Observed ms-DS-MachineAccountQuota' = $quota
        'Required quota' = 0
        'Documented AD default' = 10
        'Matches documented default' = $quota -eq 10
    })
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done.' } else { 'Set ms-DS-MachineAccountQuota to 0 and delegate computer creation explicitly.' })`n`n$metrics"
    return $ok
}
