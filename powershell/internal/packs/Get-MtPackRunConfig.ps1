function Get-MtPackRunConfig {
    <#
    .SYNOPSIS
    Returns the run config that a pack command reads its PackPolicy and Packs from: the one beside the pack lock, or $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter()] [AllowNull()] [AllowEmptyString()] [string] $ConfigPath)

    if (-not $ConfigPath -or -not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $null }
    try { Resolve-MtRunConfig -Config $ConfigPath -WarningAction SilentlyContinue } catch { Write-Warning "The Maester config '$ConfigPath' could not be read: $($_.Exception.Message)"; $null }
}
