function Write-MtSponsorMessage {
    <#
    .SYNOPSIS
    Writes the sponsor message at the end of a run: Maester runs on sponsorships, with a link to maester.dev/sponsor.

    .DESCRIPTION
    Three lines under the run summary. In an interactive console with colour the first line is drawn in
    about a second and a half: the heading is typed out after a pink heart, which then beats twice. Everywhere else
    (Stream and Plain mode, CI, redirected output, NO_COLOR) the lines are written as they are, with no
    animation, so a log has each line once.

    The frames of the animation go straight to the console; the finished lines go through
    Write-MtConsoleLine, so transcripts and the information stream have them once.

    Invoke-Maester writes it after Write-MtRunSummary unless Output.SponsorMessage is false in the run config.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output, as Pester writes it')]
    [CmdletBinding()]
    param(
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    if (-not $Console) { $Console = Get-MtConsoleMode }
    $url = 'https://maester.dev/sponsor'
    $esc = [char]27
    $heading = 'Maester runs on sponsorships'

    $pink = if (-not $Console.Ansi) { $null }
    elseif ($Console.ColorDepth -eq 'TrueColor') { '38;2;219;97;162' }
    elseif ($Console.ColorDepth -eq '256') { '38;5;205' }
    else { '35' }
    $paint = { param($text, $sgr) if ($sgr -and $Console.Ansi) { "$esc[$($sgr)m$text$esc[0m" } else { $text } }
    $full = if ($Console.Unicode) { [string][char]0x2665 } else { '<3' }
    $hollow = if ($Console.Unicode) { [string][char]0x2661 } else { '<3' }
    $line = { param($heart, $heartStyle, $text) " $(& $paint $heart $heartStyle)  $(& $paint $text '1')" }

    $animate = $Console.Mode -eq 'Interactive' -and $Console.Ansi -and -not $Console.CI -and
        -not $(try { [System.Console]::IsOutputRedirected } catch { $true })
    if ($animate) {
        try {
            [System.Console]::Write("$esc[?25l")
            $frame = { param($text, $ms) [System.Console]::Write("`r$esc[2K$text"); Start-Sleep -Milliseconds $ms }
            # The heading types itself out after the heart.
            for ($i = 2; $i -lt $heading.Length + 2; $i += 2) { & $frame (& $line $full $pink $heading.Substring(0, [math]::Min($i, $heading.Length))) 25 }
            # Two beats: the heart swells (bold) and rests (hollow, dim).
            foreach ($beat in 1..2) {
                & $frame (& $line $full "1;$pink" $heading) 120
                & $frame (& $line $hollow '2' $heading) 90
                & $frame (& $line $full "1;$pink" $heading) 120
                & $frame (& $line $full $pink $heading) 170
            }
            [System.Console]::Write("`r$esc[2K")
        } catch {
            Write-Debug "Sponsor animation: $_"
        } finally {
            try { [System.Console]::Write("$esc[?25h") } catch { Write-Debug "Cursor: $_" }
        }
    }

    $link = $url
    if ($Console.Hyperlink) { $link = "$esc]8;;$url$esc\$url$esc]8;;$esc\" }
    Write-MtConsoleLine (& $line $full $pink $heading)
    Write-MtConsoleLine "    It's free, and the people who build it rely on sponsors to keep it going."
    Write-MtConsoleLine "    $(Format-MtConsoleText 'Sponsor the people who build it:' -Style Dim -Console $Console) $(& $paint $link $pink)"
    Write-MtConsoleLine ''
}
