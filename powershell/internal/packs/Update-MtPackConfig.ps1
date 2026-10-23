function Update-MtPackConfig {
    <#
    .SYNOPSIS
    Adds, changes or removes a pack's entry in the Packs section of a maester-config.json (Maester Packs design, section 5.2).

    .DESCRIPTION
    An entry records what the user asked for: Source (owner/repo, owner/repo/folder or a local folder),
    Version (the range Update-MtPack stays within) and Enabled, plus Id so the entry can be found again. The
    rest of the file is kept as it is. A file that does not exist yet is created.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Id,
        # The entry to write; omit it with -Remove.
        [Parameter()] [System.Collections.IDictionary] $Entry,
        [Parameter()] [switch] $Remove
    )

    $config = [ordered]@{}
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $text = Get-Content -LiteralPath $Path -Raw
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            try { $config = $text | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
            catch { throw "The Maester config file '$Path' is not valid JSON, so the pack was not recorded: $($_.Exception.Message)" }
        }
    }
    $packs = [System.Collections.Generic.List[object]]::new()
    $existing = $null
    foreach ($p in @($(if ($config.Contains('Packs')) { $config['Packs'] }) | Where-Object { $_ })) {
        $same = ($p -is [System.Collections.IDictionary]) -and $p.Contains('Id') -and [string]$p['Id'] -eq $Id
        if ($same) { $existing = $p } else { $packs.Add($p) }
    }
    if (-not $Remove -and $Entry) {
        $row = [ordered]@{ Id = $Id }
        # Keep what the user set on an existing entry: Enabled, the Version range and any other keys.
        if ($existing) { foreach ($k in $existing.Keys) { if ($k -ne 'Id') { $row[$k] = $existing[$k] } } }
        foreach ($k in $Entry.Keys) {
            if ($k -eq 'Id' -or $null -eq $Entry[$k]) { continue }
            if ($k -in 'Version', 'Enabled' -and $row.Contains($k) -and $null -ne $row[$k] -and "$($row[$k])" -ne '') { continue }
            $row[$k] = $Entry[$k]
        }
        $packs.Add($row)
    }
    $config['Packs'] = @($packs | Sort-Object { if ($_ -is [System.Collections.IDictionary]) { [string]$_['Id'] } else { '' } })

    if (-not $PSCmdlet.ShouldProcess($Path, 'Record the pack in the Maester config')) { return }
    $folder = Split-Path -Path $Path -Parent
    if ($folder -and -not (Test-Path -LiteralPath $folder)) { $null = New-Item -Path $folder -ItemType Directory -Force }
    [System.IO.File]::WriteAllText($Path, ($config | ConvertTo-Json -Depth 20) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}
