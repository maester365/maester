# Helper dot-sourced by Contoso.DotSource.Tests.ps1. Not a test file.
function Get-ContosoPolicy {
    param([string] $Name)
    $all = @(
        [pscustomobject]@{ Name = 'PasswordExpiry'; Value = 0 }
        [pscustomobject]@{ Name = 'LockoutThreshold'; Value = 10 }
    )
    if ($Name) { return $all | Where-Object Name -EQ $Name }
    return $all
}
