function Get-MtBanner {
    <#
    .SYNOPSIS
    Builds the Maester banner for the console: the wordmark, the flame logo and the version.

    .DESCRIPTION
    Returns Lines (with colour when the console uses it), the Width they need, and Compact, a one-line
    replacement. The banner is 88 columns: the "ANSI Shadow" wordmark with a light outline, next to the
    Maester flame drawn with quadrant characters (two by two pixels per cell, sampled from assets/logo/maester.png).
    Both use the logo's gradient, orange at the top to red at the bottom: truecolor where the terminal
    supports it, then 256 colours, then 16. Consoles narrower than 90 columns get a small flame next to a
    two-line wordmark (37 columns).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # From Get-MtConsoleMode.
        [Parameter(Mandatory)]
        [pscustomobject] $Console
    )

    $version = Get-MtModuleVersion
    $wordmark = @(
        '███╗   ███╗ █████╗ ███████╗███████╗████████╗███████╗██████╗ '
        '████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗'
        '██╔████╔██║███████║█████╗  ███████╗   ██║   █████╗  ██████╔╝'
        '██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══╝  ██╔══██╗'
        '██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ███████╗██║  ██║'
        '╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝'
    )
    $flame = @(
        '       ▄▌       '
        '     ▄██▌       '
        '   ▄████▌  ▗    '
        '  ▟██████  ▟▙   '
        ' ▟███████▙ ██▙▖ '
        '▟██████▀██▙████▖'
        '███████  ▀██████'
        '█████▛▘   ▐▛▐███'
        '▝███▛       ▐██▘'
        ' ▝██       ▗█▛▘ '
        '   ▜       ▀▘   '
    )
    $smallWordmark = @(
        '█▀▄▀█ ▄▀█ █▀▀ █▀ ▀█▀ █▀▀ █▀█'
        '█ ▀ █ █▀█ ██▄ ▄█  █  ██▄ █▀▄'
    )
    $smallFlame = @(
        '  ▄▟   '
        '▗▟██ ▖ '
        '▟██▀██▙'
        '██▀ ▝▜█'
        '▝▀   ▝▘'
    )

    $esc = [char]27
    $reset = if ($Console.Ansi) { "$esc[0m" } else { '' }
    # The logo's gradient, top to bottom.
    $top = 247, 148, 29
    $bottom = 214, 40, 47
    $sgr = {
        param([int[]] $rgb)
        switch ($Console.ColorDepth) {
            'TrueColor' { "$esc[38;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m" }
            '256' {
                $cube = foreach ($c in $rgb) { [int][math]::Round($c / 255 * 5) }
                "$esc[38;5;$(16 + 36 * $cube[0] + 6 * $cube[1] + $cube[2])m"
            }
            '16' { if ($rgb[1] -gt 110) { "$esc[93m" } elseif ($rgb[1] -gt 70) { "$esc[91m" } else { "$esc[31m" } }
            default { '' }
        }
    }
    $rowColor = { param([int] $row, [int] $rows) & $sgr @(foreach ($i in 0..2) { [int]($top[$i] + ($bottom[$i] - $top[$i]) * $(if ($rows -gt 1) { $row / ($rows - 1) } else { 0 })) }) }
    $outline = if ($Console.Ansi) { "$esc[97m" } else { '' }
    $dim = if ($Console.Ansi) { "$esc[2m" } else { '' }

    # One line of art: block characters in the row's colour, box-drawing characters as the light outline.
    $paint = {
        param([string] $line, [string] $color)
        $sb = [System.Text.StringBuilder]::new()
        $current = $null
        foreach ($ch in $line.ToCharArray()) {
            if ($ch -ne ' ') {
                $want = if ($ch -ge [char]0x2550 -and $ch -le [char]0x256C) { $outline } else { $color }
                if ($want -ne $current) { [void]$sb.Append($want); $current = $want }
            }
            [void]$sb.Append($ch)
        }
        [void]$sb.Append($reset)
        $sb.ToString()
    }

    $tagline = "v$version · maester.dev"
    $lines = [System.Collections.Generic.List[string]]::new()
    if ($Console.Width -ge 90) {
        $width = 88
        $lines.Add("$dim┌──$reset$(' ' * ($width - 6))$dim──┐$reset")
        for ($r = 0; $r -lt $flame.Count; $r++) {
            $left = if ($r -ge 3 -and $r -le 8) { (& $paint $wordmark[$r - 3] (& $rowColor ($r - 3) 6)) + (' ' * (64 - $wordmark[$r - 3].Length)) }
            elseif ($r -eq 9) { (' ' * (60 - $tagline.Length)) + "$dim$tagline$reset" + '    ' }
            else { ' ' * 64 }
            $lines.Add("     $left $(& $paint $flame[$r] (& $rowColor $r $flame.Count))")
        }
        $lines.Add("$dim└──$reset$(' ' * ($width - 6))$dim──┘$reset")
    } else {
        $width = 37
        $text = @('', $smallWordmark[0], $smallWordmark[1], $tagline, '')
        for ($r = 0; $r -lt $smallFlame.Count; $r++) {
            $right = if ($r -in 1, 2) { & $paint $text[$r] (& $rowColor ($r - 1) 2) } elseif ($text[$r]) { "$dim$($text[$r])$reset" } else { '' }
            $lines.Add(" $(& $paint $smallFlame[$r] (& $rowColor $r $smallFlame.Count))  $right")
        }
    }

    [pscustomobject]@{
        Lines   = $lines.ToArray()
        Width   = $width
        Compact = "Maester v$version"
    }
}

function Show-MtLogo {
    <#
    .SYNOPSIS
    Writes the Maester banner, sized and coloured for the console.

    .DESCRIPTION
    Interactive consoles of 40 columns or more get the banner from Get-MtBanner. Narrower consoles, Stream
    and Plain output, and consoles without UTF-8 get one plain line.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    param (
        # From Get-MtConsoleMode.
        [Parameter()]
        [pscustomobject] $Console = (Get-MtConsoleMode)
    )

    if ($Console.Mode -ne 'Interactive' -or -not $Console.Unicode -or $Console.Width -lt 40) {
        Write-Host "Maester v$(Get-MtModuleVersion) | PowerShell $($PSVersionTable.PSVersion) | maester.dev"
        return
    }
    Write-Host ''
    Write-Host ((Get-MtBanner -Console $Console).Lines -join "`n")
}
