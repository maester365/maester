function Get-MtBanner {
    <#
    .SYNOPSIS
    Builds the Maester banner for the console: the wordmark, the flame logo and the version.

    .DESCRIPTION
    Returns Lines (with colour when the console uses it), the Width they need, and Compact, a one-line
    replacement. The banner is 88 columns: the Maester flame on the left, as on maester.dev, drawn with
    quadrant characters (two by two pixels per cell, sampled from assets/logo/maester.png), and the "ANSI Shadow" wordmark next to it. The wordmark has a
    gradient from left to right, Maester red to amber, with its shadow in a darker shade of the same colour.
    The flame has the logo's own gradient, orange at the top to red at the bottom, in two steps per row. Truecolor where the
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
        param([int[]] $rgb, [bool] $background)
        $layer = if ($background) { 48 } else { 38 }
        switch ($Console.ColorDepth) {
            'TrueColor' { "$esc[$layer;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m" }
            '256' {
                $cube = foreach ($c in $rgb) { [int][math]::Round($c / 255 * 5) }
                "$esc[$layer;5;$(16 + 36 * $cube[0] + 6 * $cube[1] + $cube[2])m"
            }
            '16' { if ($rgb[1] -gt 110) { "$esc[93m" } elseif ($rgb[1] -gt 70) { "$esc[91m" } else { "$esc[31m" } }
            default { '' }
        }
    }
    # The colour at a height of the flame, in half rows: a cell is two half rows tall.
    $flameColor = {
        param([double] $halfRow, [int] $rows)
        $t = if ($rows -gt 1) { [math]::Min(1.0, $halfRow / (2.0 * $rows - 1)) } else { 0 }
        , @(foreach ($i in 0..2) { [int]($top[$i] + ($bottom[$i] - $top[$i]) * $t) })
    }
    # With enough colours a full cell is drawn as an upper half block in the colour of its upper half, on a
    # background in the colour of its lower half: two steps of the gradient per row instead of one.
    $halfSteps = $Console.Ansi -and $Console.ColorDepth -in 'TrueColor', '256'
    # The wordmark's gradient, left to right.
    $stops = @(@(229, 36, 59), @(255, 106, 61), @(255, 181, 71))
    $columnColor = {
        param([int] $column, [int] $columns, [bool] $shadow)
        $t = if ($columns -gt 1) { $column / ($columns - 1) } else { 0 }
        $segment = [math]::Min([math]::Floor($t * ($stops.Count - 1)), $stops.Count - 2)
        $local = $t * ($stops.Count - 1) - $segment
        $rgb = foreach ($i in 0..2) { [int]($stops[$segment][$i] + ($stops[$segment + 1][$i] - $stops[$segment][$i]) * $local) }
        if ($shadow) { $rgb = foreach ($c in $rgb) { [int]($c * 0.55) } }
        & $sgr $rgb $false
    }
    $dim = if ($Console.Ansi) { "$esc[2m" } else { '' }

    # One line of the flame. Cells that are filled only at the top or only at the bottom take the colour of
    # that half; the other partly filled cells the colour of the middle of the row.
    $paintFlame = {
        param([string] $line, [int] $row, [int] $rows)
        if (-not $Console.Ansi -or -not $line.Trim()) { return $line }
        $sb = [System.Text.StringBuilder]::new()
        $current = ''
        foreach ($ch in $line.ToCharArray()) {
            $out = $ch
            $want = ''
            if ($ch -eq [char]0x2588 -and $halfSteps) {
                $out = [char]0x2580
                $want = (& $sgr (& $flameColor (2 * $row) $rows) $false) + (& $sgr (& $flameColor (2 * $row + 1) $rows) $true)
            } elseif ($ch -ne ' ') {
                $half = if ('▀▘▝'.Contains($ch)) { 0 } elseif ('▄▖▗'.Contains($ch)) { 1 } else { 0.5 }
                $want = & $sgr (& $flameColor (2 * $row + $half) $rows) $false
            }
            if ($want -ne $current) {
                if ($current) { [void]$sb.Append($reset) }
                [void]$sb.Append($want)
                $current = $want
            }
            [void]$sb.Append($out)
        }
        if ($current) { [void]$sb.Append($reset) }
        $sb.ToString()
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
            $right = if ($r -ge 3 -and $r -le 8) { & $paintWordmark $wordmark[$r - 3] 60 }
            elseif ($r -eq 9) { (' ' * (60 - $tagline.Length)) + "$dim$tagline$reset" }
            else { '' }
            $lines.Add("   $(& $paintFlame $flame[$r] $r $flame.Count)    $right".TrimEnd())
        }
        $lines.Add("$dim└──$reset$(' ' * ($width - 6))$dim──┘$reset")
    } else {
        $width = 37
        $text = @('', $smallWordmark[0], $smallWordmark[1], $tagline, '')
        for ($r = 0; $r -lt $smallFlame.Count; $r++) {
            $right = if ($r -in 1, 2) { & $paintWordmark $text[$r] $smallWordmark[0].Length } elseif ($text[$r]) { "$dim$($text[$r])$reset" } else { '' }
            $lines.Add(" $(& $paintFlame $smallFlame[$r] $r $smallFlame.Count)  $right")
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
