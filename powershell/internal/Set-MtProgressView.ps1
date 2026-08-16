function Set-MtProgressView {
    <#
    .SYNOPSIS
    Set the style of the progress bar to classic on Windows for better compatibility with the console.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: Implement ShouldProcess')]
    [CmdletBinding()]
    param ()

    try {
        if ($IsWindows -and $IsCoreCLR -and [string]::IsNullOrWhiteSpace($env:VSCODE_PID)) {
            $Script:ProgressView = $PSStyle.Progress.View
            $PSStyle.Progress.View = 'Classic'
        } else {
            $Script:ProgressView = $null
        }
    } catch {
        Write-Verbose $_
    }
}
