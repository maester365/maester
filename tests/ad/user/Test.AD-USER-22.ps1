function Test-MtAdUserBuiltInAdminCount {
    <# .SYNOPSIS
    Checks that the domain RID-500 administrator is present and not stale.
    .EXAMPLE
    Invoke-MtTest -Id AD-USER-22
    Assess the RID-500 administrator for stale access or credentials.
    .LINK
    https://maester.dev/docs/tests/AD-USER-22
    #>
    [MaesterTest(
        Id = 'AD-USER-22',
        Title = 'The built-in domain administrator should not have stale access or credentials',
        Product = 'ad',
        Feature = 'users',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.002',
        Control = 'nist-800-53-r5:AC-2(3)',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:domainDNS.objectSid:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Minimum days since the last recorded logon before enabled RID-500 usage needs review.
        [ValidateRange(15, 3650)]
        [int] $MinimumIdleDays = 30,
        # Maximum age in days of the built-in administrator password.
        [ValidateRange(1, 3650)]
        [int] $MaximumPasswordAgeDays = 180,
        # Conservative upper bound in days for replicated lastLogonTimestamp delay.
        [ValidateRange(1, 30)]
        [int] $MaximumLogonTimestampLagDays = 14
    )

    $state = Get-MtADDomainState -Categories @('Domain', 'Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $domainSid = if ($state.Domain.DomainSID -is [string]) { $state.Domain.DomainSID } else { [string]$state.Domain.DomainSID.Value }
    if ($domainSid -notmatch '^S-1-5-21-(\d+-){2}\d+$') { throw 'Domain SID is unavailable; cannot identify the RID-500 account.' }
    $admin = @($state.Users | Where-Object { ([string]$_.SID -eq "$domainSid-500") -or ([string]$_.SID.Value -eq "$domainSid-500") })
    if ($admin.Count -ne 1) { throw "Expected one domain RID-500 administrator, found $($admin.Count)." }
    $account = $admin[0]
    if ($null -eq $account.Enabled) { throw 'RID-500 enabled state is unavailable; recent-use scope cannot be established.' }
    if ($null -eq $account.PasswordLastSet) { throw 'RID-500 password last-set data is unavailable.' }
    $passwordAge = [int]((Get-Date) - [datetime]$account.PasswordLastSet).TotalDays
    $lastLogon = if ($null -eq $account.LastLogonDate) { 'Unknown' } else { [string]$account.LastLogonDate }
    $idle = if ($null -eq $account.LastLogonDate) { 'Unknown' } else { [int]((Get-Date) - [datetime]$account.LastLogonDate).TotalDays }
    $syncInterval = if ($null -eq $state.Domain.LogonTimeSyncIntervalDays) { 14 } else { [int]$state.Domain.LogonTimeSyncIntervalDays }
    if ($syncInterval -lt 0) { throw 'Domain logon-time synchronization interval is invalid.' }
    $effectiveLagDays = [math]::Max($MaximumLogonTimestampLagDays, $syncInterval)
    # Respect a configured domain interval larger than the parameter's conservative default.
    $ambiguous = $account.Enabled -eq $true -and ($idle -eq 'Unknown' -or ($idle -is [int] -and $idle -ge $MinimumIdleDays -and $idle -lt ($MinimumIdleDays + $effectiveLagDays)))
    $failed = $passwordAge -gt $MaximumPasswordAgeDays -or ($account.Enabled -eq $true -and $idle -is [int] -and $idle -lt $MinimumIdleDays)
    $metrics = Format-MtAdSummaryTable -Values ([ordered]@{
        'RID-500 account' = $account.SamAccountName
        'Account enabled' = $account.Enabled
        'Last replicated logon' = $lastLogon
        'Days since recorded logon' = $idle
        'Minimum idle period (days)' = $MinimumIdleDays
        'Password age (days)' = $passwordAge
        'Maximum password age (days)' = $MaximumPasswordAgeDays
        'Password never expires' = $account.PasswordNeverExpires
        'Conservative replication lag allowance (days)' = $effectiveLagDays
    })
    $detail = "`n`n$metrics`n`nThe replication lag allowance uses the domain interval and parameter maximum. This is not an exact all-DC last-logon audit."
    if ($failed) { Add-MtTestResultDetail -Result "Review recent RID-500 usage or rotate its old password after checking break-glass procedures. $detail" }
    elseif ($ambiguous) { Add-MtTestResultDetail -Result "RID-500 usage is ambiguous near the idle threshold; corroborate with DC logon records. $detail" -Investigate }
    else { Add-MtTestResultDetail -Result "Well done. No stale RID-500 password or confirmed recent enabled-account usage was found. $detail" }
    return (-not $failed)
}
