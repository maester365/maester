<#
.SYNOPSIS
    Set the style of the progress bar to classic on Windows for better compatibility with the console.
#>

function Set-MtProgressView {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: Implement ShouldProcess')]
    [CmdletBinding()]
    param ()

    try {
        if($IsWindows -and $IsCoreCLR) {
            $Script:ProgressView = $PSStyle.Progress.View
            $PSStyle.Progress.View = 'Classic'
        }
    }
    catch {
        Write-Verbose $_
    }
}