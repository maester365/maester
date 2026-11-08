function Assert-MtAdUserAccountControl {
    [CmdletBinding()]
    param([object[]] $Users)

    $missing = @($Users | Where-Object { $null -eq $_.UserAccountControl })
    if ($missing.Count) { throw "UserAccountControl is unavailable for $($missing.Count) users; cannot treat missing flags as clear." }
}
