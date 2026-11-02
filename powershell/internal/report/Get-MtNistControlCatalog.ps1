function Get-MtNistControlCatalog {
    <#
    .SYNOPSIS
    Returns the pinned NIST SP 800-53 control catalogue (assets/MaesterNistControls.json). Read once for the session.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if ($null -eq $script:__MtNistControlCatalog) {
        $file = Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterNistControls.json'
        $script:__MtNistControlCatalog = if (Test-Path -LiteralPath $file -PathType Leaf) { Get-Content -LiteralPath $file -Raw | ConvertFrom-Json } else { $false }
    }
    if ($script:__MtNistControlCatalog) { $script:__MtNistControlCatalog }
}
