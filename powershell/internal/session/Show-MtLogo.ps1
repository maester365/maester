function Show-MtLogo {
    <#
    .SYNOPSIS
    Writes the Maester logo and a one-line info line, sized and coloured for the console.

    .DESCRIPTION
    Interactive consoles get the wordmark with a fire gradient (red to amber, the colours of maester.dev):
    truecolor where the terminal supports it, then 256 colours, then 16. The full wordmark needs 72
    columns; a compact two-line wordmark is used down to 36 columns. Narrower consoles, Stream and Plain
    output, and consoles without UTF-8 get one plain line.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    param (
        # From Get-MtConsoleMode.
        [Parameter()]
        [pscustomobject] $Console = (Get-MtConsoleMode)
    )

    $version = Get-MtModuleVersion
    $info = "v$version · PowerShell $($PSVersionTable.PSVersion) · maester.dev"

    if ($Console.Mode -ne 'Interactive' -or -not $Console.Unicode -or $Console.Width -lt 36) {
        Write-Host "Maester $($info -replace ' · ', ' | ')"
        return
    }

    # "ANSI Shadow" wordmark (64 columns) and a compact half-block wordmark (31 columns).
    $full = @(
        '███╗   ███╗ █████╗ ███████╗███████╗████████╗███████╗██████╗ '
        '████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗'
        '██╔████╔██║███████║█████╗  ███████╗   ██║   █████╗  ██████╔╝'
        '██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══╝  ██╔══██╗'
        '██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ███████╗██║  ██║'
        '╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝'
    )
    $compact = @(
        '█▀▄▀█ ▄▀█ █▀▀ █▀ ▀█▀ █▀▀ █▀█'
        '█ ▀ █ █▀█ ██▄ ▄█  █  ██▄ █▀▄'
    )
    $art = if ($Console.Width -ge 72) { $full } else { $compact }

    $esc = [char]27
    $reset = "$esc[0m"
    $artWidth = ($art | Measure-Object -Property Length -Maximum).Maximum
    # Gradient stops: Maester red, orange, amber.
    $stops = @(@(229, 36, 59), @(255, 106, 61), @(255, 181, 71))

    $colorAt = {
        param([int] $column, [bool] $shadow)
        $t = if ($artWidth -gt 1) { $column / ($artWidth - 1) } else { 0 }
        $segment = [math]::Min([math]::Floor($t * ($stops.Count - 1)), $stops.Count - 2)
        $local = $t * ($stops.Count - 1) - $segment
        $rgb = foreach ($i in 0..2) { [int]($stops[$segment][$i] + ($stops[$segment + 1][$i] - $stops[$segment][$i]) * $local) }
        # Box-drawing shadow characters are dimmer, so the letters stand out.
        if ($shadow) { $rgb = foreach ($c in $rgb) { [int]($c * 0.55) } }
        switch ($Console.ColorDepth) {
            'TrueColor' { "$esc[38;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m" }
            '256' {
                $cube = foreach ($c in $rgb) { [int][math]::Round($c / 255 * 5) }
                "$esc[38;5;$(16 + 36 * $cube[0] + 6 * $cube[1] + $cube[2])m"
            }
            '16' { if ($shadow) { "$esc[31m" } elseif ($t -lt 0.5) { "$esc[91m" } else { "$esc[93m" } }
            default { '' }
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("`n")
    foreach ($line in $art) {
        [void]$sb.Append('  ')
        $current = $null
        for ($x = 0; $x -lt $line.Length; $x++) {
            $ch = $line[$x]
            if ($ch -ne ' ') {
                $color = & $colorAt $x ($ch -notin [char]'█', [char]'▀', [char]'▄')
                if ($color -ne $current) { [void]$sb.Append($color); $current = $color }
            }
            [void]$sb.Append($ch)
        }
        [void]$sb.Append($reset).Append("`n")
    }
    $dim = if ($Console.Ansi) { "$esc[2m" } else { '' }
    [void]$sb.Append("  $dim$info$reset`n")
    Write-Host $sb.ToString()
}
