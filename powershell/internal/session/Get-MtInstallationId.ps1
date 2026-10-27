function Get-MtInstallationId {
    <#
    .SYNOPSIS
    Returns this machine's random Maester installation ID, creating it on first use.

    .DESCRIPTION
    Telemetry counts installations with a random GUID kept in ~/.maester/installation-id. It is made here, names
    nothing about the machine or the user, and deleting the file gives a new one. When the file cannot be read or
    written, as on a read-only container, it returns a random ID kept for this PowerShell session instead, so those
    runs are still counted.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $folder = Split-Path -Path (Get-MtPackHome).UserConfig -Parent
        $path = Join-Path $folder 'installation-id'
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $id = (Get-Content -LiteralPath $path -Raw -ErrorAction Stop).Trim()
            if ($id -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { return $id }
        }
        $id = [guid]::NewGuid().ToString()
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { $null = New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop }
        Set-Content -LiteralPath $path -Value $id -NoNewline -Encoding utf8 -ErrorAction Stop
        $id
    } catch {
        Write-Verbose "No saved installation ID, using one for this session: $($_.Exception.Message)"
        if (-not $script:MtSessionInstallationId) { $script:MtSessionInstallationId = [guid]::NewGuid().ToString() }
        $script:MtSessionInstallationId
    }
}
