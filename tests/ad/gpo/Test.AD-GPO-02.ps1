function Test-MtAdGpoStale {
    <#
    .SYNOPSIS
    Checks that GPOs have been modified within the configured age limit.

    .DESCRIPTION
    Uses the cached GPO inventory. Fails when last modification is older than
    MaximumModificationAgeYears (five calendar years by default). Reports creation and modification
    dates together; an old creation date alone does not cause failure.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPO-02'

    Checks whether any GPO was last modified more than five calendar years ago.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPO-02' -Parameter @{ MaximumModificationAgeYears = 3 }

    Uses a three-year modification-age limit instead of the five-year default.

    .LINK
    https://maester.dev/docs/tests/AD-GPO-02
    #>
    [MaesterTest(
        Id                 = 'AD-GPO-02',
        Title              = 'GPOs should be modified within the configured age limit',
        Product            = 'ad',
        Feature            = 'group-policy',
        Area               = 'infrastructure',
        ResourceType       = 'GroupPolicy',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Service            = 'ActiveDirectory',
        Permission         = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author             = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum age of a GPO's last modification, in calendar years.
        [ValidateRange(1, 100)]
        [int] $MaximumModificationAgeYears = 5
    )

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState -or $null -eq $gpoState.GPOs) {
        throw 'The GPO inventory could not be retrieved; modification age cannot be assessed.'
    }
    $gpos = @($gpoState.GPOs)
    if ($gpos.Count -eq 0) { throw 'The GPO inventory is empty; modification age cannot be assessed.' }
    if (@($gpos | Where-Object { $null -eq $_.ModificationTime }).Count -gt 0) {
        throw 'One or more GPOs have no modification date; modification age cannot be assessed.'
    }
    # LDAP modification dates are UTC; keep the clock and calendar-year cutoff in UTC too.
    $cutoffDate = ([DateTimeOffset](Get-Date)).UtcDateTime.AddYears(-$MaximumModificationAgeYears)
    $stale = @($gpos | Where-Object { [datetime]$_.ModificationTime -lt $cutoffDate })
    $details = @(foreach ($gpo in ($gpos | Sort-Object DisplayName)) {
            [pscustomobject]@{
                Name = $gpo.DisplayName
                Created = if ($null -ne $gpo.CreationTime) { ([datetime]$gpo.CreationTime).ToString('yyyy-MM-dd HH:mm:ss') } else { $null }
                Modified = ([datetime]$gpo.ModificationTime).ToString('yyyy-MM-dd HH:mm:ss')
                Assessment = if ([datetime]$gpo.ModificationTime -lt $cutoffDate) { 'Stale' } else { 'Within limit' }
            }
        })
    $message = if ($stale.Count -eq 0) { 'Well done. No GPO exceeds the configured modification-age limit.' }
    else { "Review and update $($stale.Count) GPO(s) not modified within $MaximumModificationAgeYears years. Age is a hygiene indicator, not proof of insecure settings." }
    $result = Format-MtAdGpoResult -Summary $message -Metrics ([ordered]@{ 'Total GPOs' = $gpos.Count; 'Stale GPOs' = $stale.Count; 'Modification cutoff' = $cutoffDate.ToString('yyyy-MM-dd HH:mm:ss') }) -Details $details -Properties Name, Created, Modified, Assessment -Headers GPO, Created, Modified, Assessment
    Add-MtTestResultDetail -Result $result
    return ($stale.Count -eq 0)
}
