function Test-MtAdGpoStale {
    <#
    .SYNOPSIS
    Checks that GPOs have been modified within the configured age limit.

    .DESCRIPTION
    Uses the cached GPO inventory. Fails when a GPO's last modification is older than
    MaximumAgeYears (five calendar years by default). Reports creation and modification
    dates together; an old creation date alone does not cause failure.

    .EXAMPLE
    Test-MtAdGpoStale

    Returns $true when no GPO exceeds the modification-age limit.

    .LINK
    https://maester.dev/docs/tests/AD-GPO-02
    #>
    [MaesterTest(
        Id = 'AD-GPO-02',
        Title = 'GPOs should be modified within the configured age limit',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'infrastructure',
        ResourceType = 'GroupPolicy',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum age of a GPO's last modification, in calendar years.
        [ValidateRange(1, 100)]
        [int] $MaximumAgeYears = 5
    )

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState -or $null -eq $gpoState.GPOs) {
        throw 'The GPO inventory could not be retrieved; modification age cannot be assessed.'
    }

    $gpos = @($gpoState.GPOs)
    if (@($gpos | Where-Object { $null -eq $_.ModificationTime }).Count -gt 0) {
        throw 'One or more GPOs have no modification date; modification age cannot be assessed.'
    }
    $cutoffDate = (Get-Date).AddYears(-$MaximumAgeYears)
    $stale = @($gpos | Where-Object { [datetime]$_.ModificationTime -lt $cutoffDate })
    $result = "Total GPOs: $($gpos.Count). Stale GPOs: $($stale.Count). Modification cutoff: $($cutoffDate.ToString('yyyy-MM-dd HH:mm:ss')).`n`n"
    $result += "| GPO | Created | Modified | Assessment |`n| --- | --- | --- | --- |`n"
    foreach ($gpo in ($gpos | Sort-Object DisplayName)) {
        $name = ([string]$gpo.DisplayName).Replace('|', '&#124;') -replace '[\r\n]+', ' '
        $created = if ($null -ne $gpo.CreationTime) { ([datetime]$gpo.CreationTime).ToString('yyyy-MM-dd HH:mm:ss') } else { 'Unknown' }
        $modified = ([datetime]$gpo.ModificationTime).ToString('yyyy-MM-dd HH:mm:ss')
        $assessment = if ([datetime]$gpo.ModificationTime -lt $cutoffDate) { 'Stale' } else { 'Within limit' }
        $result += "| $name | $created | $modified | $assessment |`n"
    }
    $message = if ($stale.Count -eq 0) { 'Well done. No GPO exceeds the configured modification-age limit.' } else { "Review and update $($stale.Count) GPO(s) not modified within $MaximumAgeYears years. Age is a hygiene indicator, not proof of insecure settings." }
    Add-MtTestResultDetail -Result "$message`n`n$result"
    return ($stale.Count -eq 0)
}
