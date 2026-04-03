function Reset-MtProgressView {
    <#
    .SYNOPSIS
    Resets the style of the progress bar to the previous state on Windows.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: Implement ShouldProcess')]
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
