function Get-MtBanner {
    <#
    .SYNOPSIS
    Builds the Maester banner for the console: the wordmark, the flame logo and the version.

    .DESCRIPTION
    Returns Lines (with colour when the console uses it), the Width they need, and Compact, a one-line
    replacement. The banner is 88 columns: the "ANSI Shadow" wordmark next to the Maester flame drawn with
    quadrant characters (two by two pixels per cell, sampled from assets/logo/maester.png). The wordmark has a
    gradient from left to right, Maester red to amber, with its shadow in a darker shade of the same colour.
    The flame has the logo's own gradient, orange at the top to red at the bottom. Truecolor where the
    terminal supports it, then 256 colours, then 16. Consoles narrower than 90 columns get a small flame next to a
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
    # The wordmark's gradient, left to right.
    $stops = @(@(229, 36, 59), @(255, 106, 61), @(255, 181, 71))
    $columnColor = {
        param([int] $column, [int] $columns, [bool] $shadow)
        $t = if ($columns -gt 1) { $column / ($columns - 1) } else { 0 }
        $segment = [math]::Min([math]::Floor($t * ($stops.Count - 1)), $stops.Count - 2)
        $local = $t * ($stops.Count - 1) - $segment
        $rgb = foreach ($i in 0..2) { [int]($stops[$segment][$i] + ($stops[$segment + 1][$i] - $stops[$segment][$i]) * $local) }
        if ($shadow) { $rgb = foreach ($c in $rgb) { [int]($c * 0.55) } }
        & $sgr $rgb
    }
    $dim = if ($Console.Ansi) { "$esc[2m" } else { '' }

    # One line of the flame, in the row's colour.
    $paint = {
        param([string] $line, [string] $color)
        if ($line.Trim()) { "$color$line$reset" } else { $line }
    }
    # One line of the wordmark: each column in its colour, and the box-drawing shadow characters darker.
    $paintWordmark = {
        param([string] $line, [int] $columns)
        $sb = [System.Text.StringBuilder]::new()
        $current = $null
        for ($x = 0; $x -lt $line.Length; $x++) {
            $ch = $line[$x]
            if ($ch -ne ' ') {
                $want = & $columnColor $x $columns ($ch -ge [char]0x2550 -and $ch -le [char]0x256C)
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
            $left = if ($r -ge 3 -and $r -le 8) { (& $paintWordmark $wordmark[$r - 3] 60) + (' ' * (64 - $wordmark[$r - 3].Length)) }
            elseif ($r -eq 9) { (' ' * (60 - $tagline.Length)) + "$dim$tagline$reset" + '    ' }
            else { ' ' * 64 }
            $lines.Add("     $left $(& $paint $flame[$r] (& $rowColor $r $flame.Count))")
        }
        $lines.Add("$dim└──$reset$(' ' * ($width - 6))$dim──┘$reset")
    } else {
        $width = 37
        $text = @('', $smallWordmark[0], $smallWordmark[1], $tagline, '')
        for ($r = 0; $r -lt $smallFlame.Count; $r++) {
            $right = if ($r -in 1, 2) { & $paintWordmark $text[$r] $smallWordmark[0].Length } elseif ($text[$r]) { "$dim$($text[$r])$reset" } else { '' }
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
