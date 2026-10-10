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
    $iTermVersion = if ($termProgram -eq 'iTerm.app' -and $env:TERM_PROGRAM_VERSION -match '^(\d+\.\d+(\.\d+)?)') { [version]$Matches[1] } else { $null }
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
        # OSC 9;4 (taskbar or tab progress): older iTerm2 shows OSC 9 as a notification instead.
        Taskbar    = $interactive -and ($env:WT_SESSION -or $env:ConEmuANSI -eq 'ON' -or $termProgram -eq 'ghostty' -or ($iTermVersion -and $iTermVersion -ge [version]'3.6.6'))
        # OSC 8 hyperlinks: terminals that ignore them print the text without the link.
        Hyperlink  = $interactive -and ($env:WT_SESSION -or $termProgram -in 'vscode', 'iTerm.app', 'WezTerm', 'ghostty', 'WarpTerminal' -or [int]"0$env:VTE_VERSION" -ge 5000)
    }
}
