function Format-MtPackPanel {
    <#
    .SYNOPSIS
    Returns the console lines of a pack's card: its code, name and version, its ID and publisher, and its description, in an outlined box.

    .DESCRIPTION
    The install prompt (Show-MtPackApproval) and the message after an install (Install-MtPack) show a pack
    this way. Text from the pack must already be cleaned with ConvertTo-MtPackSafeText. The box fits the
    console, from 50 to 96 columns, and uses plain characters where the console has no Unicode.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Code,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Name,
        [Parameter()] [AllowEmptyString()] [string] $Version,
        [Parameter()] [AllowEmptyString()] [string] $Id,
        [Parameter()] [AllowEmptyString()] [string] $Publisher,
        [Parameter()] [AllowEmptyString()] [string] $Description,
        # A word above the box, such as 'Install a Maester Pack'.
        [Parameter()] [AllowEmptyString()] [string] $Title,
        [Parameter()] [ValidateSet('Passed', 'Failed', 'Error', 'Investigate', 'Dim', 'Bold', 'Accent')] [string] $Border = 'Accent',
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )

    if (-not $Console) { $Console = Get-MtConsoleMode }
    $u = [bool]$Console.Unicode
    $tl, $tr, $bl, $br, $h, $v = if ($u) { '╭', '╮', '╰', '╯', '─', '│' } else { '+', '+', '+', '+', '-', '|' }
    $inner = [math]::Max(46, [math]::Min(92, [int]$Console.Width - 8))
    $style = { param($text, $s) Format-MtConsoleText $text -Style $s -Console $Console }

    # Each row is a list of (text, style) parts; the box is drawn round their plain width.
    $rows = [System.Collections.Generic.List[object]]::new()
    $right = if ($Version) { "v$Version" } else { '' }
    $nameRoom = $inner - $Code.Length - 3 - $right.Length - 2
    $shownName = if ($Name.Length -gt $nameRoom) { $Name.Substring(0, [math]::Max(0, $nameRoom - 1)) + $(if ($u) { '…' } else { '.' }) } else { $Name }
    $gap = [math]::Max(1, $inner - $Code.Length - 3 - $shownName.Length - $right.Length)
    $rows.Add(@(@($Code, 'Accent', $true), @('   '), @($shownName, 'Bold'), @(' ' * $gap), @($right, 'Dim')))
    $about = @(@($Id, $(if ($Publisher) { "by $Publisher" })) | Where-Object { $_ }) -join $(if ($u) { ' · ' } else { ' - ' })
    if ($about) { $rows.Add(@(, @($about, 'Dim'))) }
    if ($Description) {
        $rows.Add(@(, @('')))
        $line = ''
        foreach ($word in ($Description -split '\s+' | Where-Object { $_ })) {
            if ($line -and ($line.Length + 1 + $word.Length) -gt $inner) { $rows.Add(@(, @($line))); $line = $word }
            else { $line = if ($line) { "$line $word" } else { $word } }
        }
        if ($line) { $rows.Add(@(, @($line))) }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $top = if ($Title) { "$tl$h $Title $($h * [math]::Max(1, $inner - $Title.Length - 1))$tr" } else { "$tl$($h * ($inner + 2))$tr" }
    $lines.Add('  ' + (& $style $top $Border))
    foreach ($row in $rows) {
        $plain = 0
        $text = foreach ($part in $row) {
            $t = [string]$part[0]
            if ($t.Length -gt $inner - $plain) { $t = $t.Substring(0, [math]::Max(0, $inner - $plain)) }
            $plain += $t.Length
            if ($part.Count -ge 2 -and $part[1] -and $t) {
                $styled = & $style $t $part[1]
                if ($part.Count -ge 3 -and $part[2] -and $Console.Ansi) { $styled = "$([char]27)[1m$styled" }
                $styled
            } else { $t }
        }
        $lines.Add('  ' + (& $style $v $Border) + ' ' + ($text -join '') + (' ' * ($inner - $plain)) + ' ' + (& $style $v $Border))
    }
    $lines.Add('  ' + (& $style "$bl$($h * ($inner + 2))$br" $Border))
    $lines.ToArray()
}
