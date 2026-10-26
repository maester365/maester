function Write-MtPackLock {
    <#
    .SYNOPSIS
    Writes maester-packs.lock.json, sorted so that a change shows as a small diff in a pull request.

    .DESCRIPTION
    Packs are sorted by Id and modules by Name and Version. The file is written to a temporary file next to
    it and then moved into place, so a lock file is never left half written.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [pscustomobject] $Lock
    )

    $ordered = [ordered]@{
        LockVersion = 1
        Packs       = @($Lock.Packs | Where-Object { $_ } | Sort-Object { $_.Id })
        Modules     = @($Lock.Modules | Where-Object { $_ } | Sort-Object { $_.Name }, { $_.Version })
    }
    if (-not $PSCmdlet.ShouldProcess($Path, 'Write the pack lock file')) { return }
    $folder = Split-Path -Path $Path -Parent
    if ($folder -and -not (Test-Path -LiteralPath $folder)) { $null = New-Item -Path $folder -ItemType Directory -Force }
    $temporary = "$Path.$([guid]::NewGuid().ToString('n')).tmp"
    [System.IO.File]::WriteAllText($temporary, ($ordered | ConvertTo-Json -Depth 20) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}
