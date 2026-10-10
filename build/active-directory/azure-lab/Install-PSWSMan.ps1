<#
.SYNOPSIS
    Installs PowerShell remoting dependencies on Ubuntu runners.

.DESCRIPTION
    Can either emit a shell script for Azure VM run-command usage or execute the
    installation locally. The generated script installs PowerShell if needed,
    adds smbclient and git for lab operations, installs the PSWSMan module, and
    enables OpenWSMan support for PowerShell remoting.

.PARAMETER EmitScript
    Output the bash script instead of executing it locally.

.EXAMPLE
    ./Install-PSWSMan.ps1 -EmitScript

    Emits the shell script used to prepare the Ubuntu runner.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$EmitScript
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PSWSManInstallScript {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return @'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y ca-certificates curl wget gnupg apt-transport-https software-properties-common git smbclient

if ! command -v pwsh >/dev/null 2>&1; then
    wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
    sudo dpkg -i /tmp/packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y powershell
fi

pwsh -NoLogo -NoProfile -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; if (-not (Get-Module -ListAvailable -Name PSWSMan)) { Install-Module -Name PSWSMan -Scope AllUsers -Force }; Install-WSMan"

pwsh -NoLogo -NoProfile -Command "@(Get-Module -ListAvailable -Name ActiveDirectory,GroupPolicy,DnsServer).Count"
'@
}

$scriptText = Get-PSWSManInstallScript

if ($EmitScript.IsPresent) {
    return $scriptText
}

$temporaryFile = [System.IO.Path]::GetTempFileName()
try {
    Set-Content -LiteralPath $temporaryFile -Value $scriptText -Encoding utf8
    $bashCommand = Get-Command -Name 'bash' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $bashCommand) {
        throw 'bash is required to execute the PSWSMan installation locally.'
    }

    & $bashCommand.Source $temporaryFile
    if ($LASTEXITCODE -ne 0) {
        throw "Local PSWSMan installation failed with exit code $LASTEXITCODE."
    }
} finally {
    Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
}
