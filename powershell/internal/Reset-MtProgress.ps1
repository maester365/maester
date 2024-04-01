<#
.SYNOPSIS
    Resets the style of the progress bar to the previous state on Windows.
#>

Function Reset-MtProgressView {
    [CmdletBinding()]
    param ()

    try {
        if ($IsWindows -and $IsCoreCLR) {
            $PSStyle.Progress.View = $Script:ProgressView
        }
    } catch {
        Write-Verbose $_
    }
}