function Test-MtAdUserOrdinaryIdentity {
    [CmdletBinding()]
    [OutputType([bool])]
    param([object] $User)

    if ($User.IsCriticalSystemObject -eq $true -or $null -ne $User.SecondaryKrbtgtNumber -or
        @($User.KrbtgtLinkBacklinks | Where-Object { $null -ne $_ }).Count -gt 0 -or
        $User.SamAccountName -like 'krbtgt_AzureAD*') { return $false }
    $sid = if ($User.Sid -is [string]) { $User.Sid } else { [string]$User.Sid.Value }
    if ([string]::IsNullOrWhiteSpace($sid)) { throw 'User SID is unavailable; protected-account exclusions cannot be established.' }
    if ($sid -match '-(500|501|502|503)$') { return $false }
    return $true
}
