function Get-MtConsoleMode {
    <#
    .SYNOPSIS
    Decides how Invoke-Maester writes to the console: Interactive, Stream or Plain, and what the terminal supports.

    .DESCRIPTION
    Interactive draws a live status region and is used only on a real console (ConsoleHost with virtual
    terminal support, output not redirected, not CI). Stream writes lines only (CI, redirected output, other
    hosts, -NonInteractive). Plain is Stream without colour or Unicode symbols (TERM=dumb, or chosen).

    The mode comes from -Requested when it is not Auto, then the MAESTER_OUTPUT_MODE environment variable,
    then detection. NO_COLOR turns colour off in every mode.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Interactive, Stream, Plain or Auto (detect).
        [Parameter()]
        [ValidateSet('Auto', 'Interactive', 'Stream', 'Plain')]
        [string] $Requested = 'Auto',

        # Invoke-Maester -NonInteractive: never Interactive.
        [Parameter()]
        [switch] $NonInteractive
    )

    $ci = if ($env:GITHUB_ACTIONS -eq 'true') { 'GitHubActions' }
    elseif ($env:TF_BUILD -eq 'True') { 'AzureDevOps' }
    elseif ($env:CI -and $env:CI -ne 'false') { 'Other' }
    else { $null }

    $redirected = try { [System.Console]::IsOutputRedirected } catch { $true }
    $vt = [bool]$Host.UI.SupportsVirtualTerminal
    $isConsoleHost = $Host.Name -eq 'ConsoleHost'
    $dumb = $env:TERM -eq 'dumb'

    $mode = $Requested
    if ($mode -eq 'Auto' -and $env:MAESTER_OUTPUT_MODE -in 'Interactive', 'Stream', 'Plain') { $mode = $env:MAESTER_OUTPUT_MODE }
    if ($mode -eq 'Auto') {
        $mode = if ($dumb) { 'Plain' }
        elseif ($ci -or $redirected -or $NonInteractive -or -not $isConsoleHost -or -not $vt) { 'Stream' }
        else { 'Interactive' }
    }
    # The live region needs a console it can move the cursor on, whatever was asked for.
    if ($mode -eq 'Interactive' -and ($redirected -or -not $vt -or -not $isConsoleHost)) { $mode = 'Stream' }

    $noColor = -not [string]::IsNullOrEmpty($env:NO_COLOR) -or $dumb -or $PSStyle.OutputRendering -eq 'PlainText'
    $ansi = $mode -ne 'Plain' -and -not $noColor -and ($vt -or $ci -eq 'GitHubActions')
    $utf8 = try { [System.Console]::OutputEncoding.CodePage -eq 65001 } catch { $false }

    $termProgram = "$env:TERM_PROGRAM"
    $colorDepth = if (-not $ansi) { 'None' }
    elseif ($env:COLORTERM -in 'truecolor', '24bit' -or $env:WT_SESSION -or $termProgram -in 'vscode', 'iTerm.app', 'WezTerm', 'WarpTerminal', 'ghostty') { 'TrueColor' }
    elseif ($env:TERM -like '*256color*') { '256' }
    else { '16' }

    $width = 80
    try { if ($Host.UI.RawUI.WindowSize.Width -gt 0) { $width = $Host.UI.RawUI.WindowSize.Width } } catch { Write-Debug "No console width: $_" }

    $interactive = $mode -eq 'Interactive'
    [pscustomobject]@{
        PSTypeName = 'Maester.ConsoleMode'
        Mode       = $mode
        CI         = $ci
        Ansi       = $ansi
        ColorDepth = $colorDepth
        Unicode    = $mode -ne 'Plain' -and $utf8
        Width      = $width
        # OSC 9;4, progress on the taskbar button and the tab: only where it is shown outside the window
        # (Windows Terminal, ConEmu). iTerm2 and Ghostty draw it as a line across the top of the window,
        # which only repeats the progress bar of the dashboard under it, so they do not get it.
        Taskbar    = $interactive -and ($env:WT_SESSION -or $env:ConEmuANSI -eq 'ON')
        # OSC 8 hyperlinks: terminals that ignore them print the text without the link.
        Hyperlink  = $interactive -and ($env:WT_SESSION -or $termProgram -in 'vscode', 'iTerm.app', 'WezTerm', 'ghostty', 'WarpTerminal' -or [int]"0$env:VTE_VERSION" -ge 5000)
    }
}

function Enable-MtConsoleUtf8 {
    <#
    .SYNOPSIS
    Switches the console to UTF-8 output for an interactive run on Windows, so that the dashboard can be drawn.

    .DESCRIPTION
    A Windows console starts with the output code page of the system (437, 850 and the like), in which the
    symbols, the box borders and the flame of the dashboard cannot be written, so the run falls back to plain
    characters. Windows Terminal and the terminal of VS Code can show them: there the run switches the console
    to UTF-8 and Restore-MtConsoleEncoding puts the earlier encoding back when the run ends. Other Windows
    consoles are left alone, because their fonts often lack these characters.

    Returns whether the encoding was changed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    if (-not $IsWindows -or -not ($env:WT_SESSION -or $env:TERM_PROGRAM -eq 'vscode')) { return $false }
    try {
        if ([System.Console]::IsOutputRedirected -or [System.Console]::OutputEncoding.CodePage -eq 65001) { return $false }
        $earlier = [System.Console]::OutputEncoding
        [System.Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $script:__MtConsoleEncoding = $earlier
        return $true
    } catch {
        Write-Debug "Could not switch the console to UTF-8: $_"
        return $false
    }
}

function Restore-MtConsoleEncoding {
    <#
    .SYNOPSIS
    Puts back the console output encoding that Enable-MtConsoleUtf8 replaced. Safe to call when nothing was changed.
    #>
    [CmdletBinding()]
    param()
    if (-not $script:__MtConsoleEncoding) { return }
    try { [System.Console]::OutputEncoding = $script:__MtConsoleEncoding } catch { Write-Debug "Could not restore the console encoding: $_" }
    $script:__MtConsoleEncoding = $null
}
