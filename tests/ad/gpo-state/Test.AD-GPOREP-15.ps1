function Test-MtAdGpoVersionMismatchCount {
    <#
    .SYNOPSIS
    Checks for mismatched Active Directory and SYSVOL GPO versions.

    .DESCRIPTION
    Lists policies with differing directory and GPT.INI versions; incomplete comparisons are errors.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOREP-15'

    Fails when directory and SYSVOL versions differ for a GPO.

    .LINK
    https://maester.dev/docs/tests/AD-GPOREP-15
    #>
    [MaesterTest(
        Id                 = 'AD-GPOREP-15',
        Title              = 'GPO directory and SYSVOL versions should match',
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
    param()

    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOReports -or $null -eq $state.GPOs) {
        throw 'GPO version reports or GPO metadata could not be collected.'
    }
    $reports = @($state.GPOReports | Where-Object { $null -ne $_ })
    if ($reports.Count -eq 0 -or $reports.Count -ne @($state.GPOs).Count) { throw 'GPO version report count is empty or does not match GPO inventory.' }
    $incomplete = @($reports | Where-Object {
            $null -eq $_.HasVersionMismatch -or $null -eq $_.DirectoryVersion -or $null -eq $_.SysvolVersion
        })
    if ($incomplete.Count -gt 0) { throw "Version comparison incomplete for $($incomplete.Count) GPOs; verify SYSVOL collection and GPT.INI access." }
    $mismatched = @($reports | Where-Object { $true -eq $_.HasVersionMismatch })
    $pass = $mismatched.Count -eq 0
    $message = if ($pass) { "Well done. All $($reports.Count) GPO directory and SYSVOL versions match." }
    else { "$($mismatched.Count) of $($reports.Count) GPOs have different directory and SYSVOL versions; investigate replication and GPT.INI." }
    $result = Format-MtAdGpoResult -Summary $message -Metrics ([ordered]@{ 'Total GPOs' = $reports.Count; 'GPOs with version mismatches' = $mismatched.Count }) -Details @($mismatched | Sort-Object Name) -Properties Name, DirectoryVersion, SysvolVersion -Headers GPO, 'Directory version', 'SYSVOL version'
    Add-MtTestResultDetail -Result $result
    return $pass
}
