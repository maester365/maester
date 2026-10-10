function Write-MtConsoleLine {
    <#
    .SYNOPSIS
    Writes a line to the host, erasing the live status region of an interactive run first.

    .DESCRIPTION
    While the console renderer is drawing (an interactive run), host output would land on top of its region,
    so the region is paused around the write. The line goes through Write-Host, so it reaches the information
    stream and transcripts. Pass colour as ANSI sequences in the text (see Get-MtConsoleMode).Ansi.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output, as Pester writes it')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Text
    )

    $renderer = $script:__MtConsoleRenderer
    if ($renderer) {
        $renderer.Pause()
        try { Write-Host $Text } finally { $renderer.Resume() }
    } else {
        Write-Host $Text
    }
}

function New-MtConsoleRenderer {
    <#
    .SYNOPSIS
    Creates the console renderer of an interactive run and makes it the session's renderer.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    [OutputType([Maester.Engine.MtConsoleRenderer])]
    param([Parameter(Mandatory)] [pscustomobject] $Console)
    $renderer = [Maester.Engine.MtConsoleRenderer]::new()
    $renderer.Ansi = $Console.Ansi
    $renderer.Unicode = $Console.Unicode
    $renderer.TaskbarProgress = $Console.Taskbar
    $script:__MtConsoleRenderer = $renderer
    $renderer
}

function Stop-MtConsoleOutput {
    <#
    .SYNOPSIS
    Erases the status line or live region of an interactive run and restores the cursor. Safe to call more than once.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Restores the console only.')]
    [CmdletBinding()]
    param()
    if ($script:__MtConsoleRenderer) {
        try { $script:__MtConsoleRenderer.Stop() } catch { Write-Debug "Console renderer stop failed: $_" }
        $script:__MtConsoleRenderer = $null
    }
}
