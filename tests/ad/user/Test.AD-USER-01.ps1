function Test-MtAdUserDisabledCount {
    <# .SYNOPSIS
    Checks whether disabled ordinary users have exceeded the retention period.
    .EXAMPLE
    Invoke-MtTest -Id AD-USER-01
    Assess disabled ordinary users against the retention period.
    .LINK
    https://maester.dev/docs/tests/AD-USER-01
    #>
    [MaesterTest(
        Id = 'AD-USER-01',
        Title = 'Disabled users should be removed after the retention period',
        Product = 'ad',
        Feature = 'users',
        Area = 'identity-lifecycle',
        ResourceType = 'User',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.002',
        Control = 'nist-800-53-r5:AC-2(3)',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum days since the last local modification of a disabled user before review.
        [ValidateRange(1, 3650)]
        [int] $RetentionDays = 180
    )

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    if (@($state.Users | Where-Object { $null -eq $_.Enabled }).Count -gt 0) { throw 'User enabled state is missing; disabled-account scope cannot be established.' }
    $old = @($state.Users | Where-Object {
        if ($_.Enabled -ne $false -or -not (Test-MtAdUserOrdinaryIdentity $_)) { return $false }
        if ($null -eq $_.Modified) { throw "Modification time missing for $($_.SamAccountName)." }
        [datetime]$_.Modified -lt (Get-Date).AddDays(-$RetentionDays)
    })
    $table = Format-MtAdUserSecurityTable -Rows $old -Columns @('SamAccountName', 'Modified', 'DistinguishedName')
    if ($old.Count) { Add-MtTestResultDetail -Result "Found $($old.Count) disabled ordinary users last modified more than $RetentionDays days ago; review retention and remove when approved. Modification time is not a disable date and may change for other reasons. Local whenChanged is not replicated.`n`n$table" }
    else { Add-MtTestResultDetail -Result "Well done. No disabled ordinary user exceeds the $RetentionDays-day modification-age review threshold. This does not prove when each account was disabled." }
    return ($old.Count -eq 0)
}
