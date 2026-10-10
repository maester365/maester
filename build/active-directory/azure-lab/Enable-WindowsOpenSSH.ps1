<#
.SYNOPSIS
    Enables and configures OpenSSH Server on a Windows VM for SSH-based management.

.DESCRIPTION
    This script installs and configures OpenSSH Server on Windows Server 2022 as an
    alternative management channel to Azure VM Run Commands. This is particularly
    useful for Active Directory operations that fail under the Azure VM Agent service
    context due to Kerberos credential delegation limitations.

    The script:
    1. Installs the OpenSSH Server optional feature
    2. Configures the sshd service to start automatically
    3. Sets up firewall rules for SSH (port 22)
    4. Configures PowerShell as the default SSH shell
    5. Optionally configures key-based authentication

    Based on patterns from: https://github.com/soulemike/microsoft-skills/tree/main/skills/vm-guest-management

.PARAMETER PublicKey
    Optional SSH public key to add to the administrators authorized_keys file.

.PARAMETER DisablePasswordAuthentication
    When specified, disables password authentication (only use after verifying key-based auth works).

.EXAMPLE
    ./Enable-WindowsOpenSSH.ps1 -PublicKey 'ssh-ed25519 AAAAC3NzaC...'

    Enables OpenSSH Server and configures the provided public key for authentication.

.NOTES
    Requires administrative privileges.

    For AD domain operations (e.g., child domain promotion), SSH may provide a different
    execution context than Azure VM Run Commands. However, Kerberos credential delegation
    still requires a domain-joined orchestrator or interactive session for some operations.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$PublicKey,

    [Parameter()]
    [switch]$DisablePasswordAuthentication
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Verbose 'Installing OpenSSH Server...'

# Install OpenSSH Server (available as optional feature in Windows Server 2022)
$sshServerFeature = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
if ($sshServerFeature.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name $sshServerFeature.Name | Out-Null
    Write-Verbose 'OpenSSH Server installed successfully.'
}
else {
    Write-Verbose 'OpenSSH Server is already installed.'
}

# Start and configure the sshd service
$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if (-not $sshdService) {
    throw 'OpenSSH Server service (sshd) not found after installation.'
}

if ($sshdService.StartType -ne 'Automatic') {
    Set-Service -Name sshd -StartupType Automatic
    Write-Verbose 'Set sshd service to start automatically.'
}

if ($sshdService.Status -ne 'Running') {
    Start-Service -Name sshd
    Write-Verbose 'Started sshd service.'
}

# Configure firewall rule for SSH
$firewallRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $firewallRule) {
    New-NetFirewallRule `
        -Name 'OpenSSH-Server-In-TCP' `
        -DisplayName 'OpenSSH Server (sshd)' `
        -Description 'Inbound rule for OpenSSH Server' `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 22 `
        -Action Allow | Out-Null
    Write-Verbose 'Created firewall rule for SSH.'
}
else {
    Write-Verbose 'Firewall rule for SSH already exists.'
}

# Set PowerShell as the default SSH shell
$defaultShellPath = (Get-Command -Name 'powershell.exe').Source
$registryPath = 'HKLM:\SOFTWARE\OpenSSH'
if (-not (Test-Path -Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

$existingDefaultShell = Get-ItemProperty -Path $registryPath -Name 'DefaultShell' -ErrorAction SilentlyContinue
if (-not $existingDefaultShell -or $existingDefaultShell.DefaultShell -ne $defaultShellPath) {
    Set-ItemProperty -Path $registryPath -Name 'DefaultShell' -Value $defaultShellPath
    Write-Verbose 'Set PowerShell as default SSH shell.'
}

# Configure authorized_keys if public key provided
if ($PublicKey) {
    $adminProfilePath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-18' -Name 'ProfileImagePath').ProfileImagePath
    $sshDir = Join-Path -Path $adminProfilePath -ChildPath '.ssh'
    $authorizedKeysPath = Join-Path -Path $sshDir -ChildPath 'authorized_keys'

    if (-not (Test-Path -Path $sshDir)) {
        New-Item -Path $sshDir -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -Path $authorizedKeysPath) -or (Get-Content -Path $authorizedKeysPath -Raw) -notcontains $PublicKey) {
        Add-Content -Path $authorizedKeysPath -Value $PublicKey -Encoding utf8
        Write-Verbose 'Added public key to authorized_keys.'
    }

    # Set proper permissions on .ssh directory and authorized_keys
    $acl = Get-Acl -Path $sshDir
    $acl.SetAccessRuleProtection($true, $false)
    Set-Acl -Path $sshDir -AclObject $acl

    $acl = Get-Acl -Path $authorizedKeysPath
    $acl.SetAccessRuleProtection($true, $false)
    Set-Acl -Path $authorizedKeysPath -AclObject $acl
}

# Optional: Disable password authentication (only after verifying key-based auth)
if ($DisablePasswordAuthentication.IsPresent) {
    $sshdConfigPath = Join-Path -Path $env:ProgramData -ChildPath 'ssh\sshd_config'
    if (Test-Path -Path $sshdConfigPath) {
        $sshdConfig = Get-Content -Path $sshdConfigPath -Raw
        if ($sshdConfig -notmatch '^PasswordAuthentication no') {
            $sshdConfig = $sshdConfig -replace '^#?PasswordAuthentication.*$', 'PasswordAuthentication no'
            $sshdConfig | Set-Content -Path $sshdConfigPath -Encoding utf8
            Write-Verbose 'Disabled password authentication in sshd_config.'
        }
    }
}

# Restart sshd to apply changes
Restart-Service -Name sshd -Force
Write-Verbose 'Restarted sshd service to apply configuration.'

# Verify SSH is reachable
$sshTest = Test-NetConnection -ComputerName localhost -Port 22 -WarningAction SilentlyContinue
if (-not $sshTest.TcpTestSucceeded) {
    throw 'SSH service is not reachable on port 22 after configuration.'
}

Write-Verbose 'OpenSSH Server configuration complete.'

return [pscustomobject][ordered]@{
    ServiceStatus      = (Get-Service -Name sshd).Status
    FirewallRuleExists = $null -ne (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)
    DefaultShell       = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' -ErrorAction SilentlyContinue).DefaultShell
    SshReachable       = $sshTest.TcpTestSucceeded
}
