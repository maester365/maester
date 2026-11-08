function Test-MtAdUserDormantEnabledCount {
    <# .SYNOPSIS
    Checks for enabled users with old recorded logon timestamps.
    #>
    [MaesterTest(Id = 'AD-USER-02', Title = 'Enabled users should not remain dormant', Product = 'ad', Feature = 'users', Area = 'identity-lifecycle', ResourceType = 'User', Severity = 'Medium', UserImpact = 'Low', ImplementationCost = 'Medium', Mitre = 'T1078.002', Control = 'nist-800-53-r5:AC-2(3)', Service = 'ActiveDirectory', Permission = 'ActiveDirectory:Ldap:user:ReadProperty', Author = 'soulemike')]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Number of days since the recorded logon after which an enabled account is dormant.
        [ValidateRange(15, 3650)]
        [int] $DormantThresholdDays = 90
    )

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    if (@($state.Users | Where-Object { $null -eq $_.Enabled }).Count -gt 0) { throw 'User enabled state is missing; dormancy scope cannot be established.' }
    $old = @($state.Users | Where-Object { $_.Enabled -eq $true -and $null -ne $_.LastLogonDate -and [datetime]$_.LastLogonDate -lt (Get-Date).AddDays(-$DormantThresholdDays) })
    $unknown = @($state.Users | Where-Object { $_.Enabled -eq $true -and $null -eq $_.LastLogonDate })
    $table = Format-MtAdUserSecurityTable -Rows $old -Columns @('SamAccountName', 'LastLogonDate', 'DistinguishedName')
    if ($old.Count) { Add-MtTestResultDetail -Result "Found $($old.Count) enabled users with a recorded logon older than $DormantThresholdDays days. Review and disable unneeded identities; $($unknown.Count) enabled users lack a logon date and need separate review. Replicated lastLogonTimestamp can lag by about 14 days.`n`n$table" }
    elseif ($unknown.Count) { Add-MtTestResultDetail -Result "No old logons found, but $($unknown.Count) enabled users lack a recorded logon date. Review them before treating this as clean." -Investigate }
    else { Add-MtTestResultDetail -Result "Well done. No enabled user has a recorded logon older than $DormantThresholdDays days (replicated timestamps can lag)." }
    return ($old.Count -eq 0)
}
