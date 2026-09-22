<#
.SYNOPSIS
    Creates and promotes one Windows domain controller for the Azure lab.

.DESCRIPTION
    Creates the NIC and VM for a single domain controller, stages a startup task
    that promotes the server into the requested forest or domain, configures a
    self-signed LDAPS certificate, enables WinRM HTTPS and Negotiate, and creates
    a low-privilege reader account for Maester validation.

.PARAMETER DomainRole
    Deployment role for the VM: RootForest, ChildDomain, or SeparateForest.

.PARAMETER DomainName
    FQDN for the forest or child domain hosted on the VM.

.PARAMETER ParentDomainName
    Parent domain FQDN used only for ChildDomain promotion.

.PARAMETER ParentDnsServer
    DNS server IP used to bootstrap child domain promotion.

.PARAMETER PromotionUserName
    Domain credential used for child domain promotion.

.PARAMETER PromotionPassword
    Password for the promotion credential.

.EXAMPLE
    ./New-DomainController.ps1 -VmName MiSouleDC02 -DomainRole RootForest -DomainName misoule02.local

    Creates the root forest controller for misoule02.local.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'PromotionPassword',
    Justification = 'Passwords are generated at runtime, optionally stored in Key Vault, and passed to Azure CLI run-command as ephemeral values.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'AdminPassword',
    Justification = 'Azure CLI VM creation requires a plain-text password argument at execution time.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'SafeModePassword',
    Justification = 'The script provisions short-lived lab credentials and does not embed static secrets.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'TestUserPassword',
    Justification = 'The test account password is generated per deployment and not stored in source control.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'DomainJoinUserPassword',
    Justification = 'The delegated join-account password is generated per deployment and passed only at provisioning time.'
)]
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ResourceGroupName = 'RG_5100_MiSoule_2',

    [Parameter()]
    [string]$Location = 'eastus',

    [Parameter()]
    [string]$VNetName = 'MiSouleADTestVNet',

    [Parameter()]
    [string]$SubnetName = 'LabSubnet',

    [Parameter(Mandatory)]
    [string]$VmName,

    [Parameter(Mandatory)]
    [string]$PrivateIpAddress,

    [Parameter(Mandatory)]
    [ValidateSet('RootForest', 'ChildDomain', 'SeparateForest')]
    [string]$DomainRole,

    [Parameter(Mandatory)]
    [string]$DomainName,

    [Parameter(Mandatory)]
    [string]$DomainNetbiosName,

    [Parameter()]
    [string]$ParentDomainName,

    [Parameter()]
    [string]$ParentDnsServer,

    [Parameter()]
    [string]$PromotionUserName,

    [Parameter()]
    [string]$PromotionPassword,

    [Parameter()]
    [string]$AdminUsername = 'labadmin',

    [Parameter(Mandatory)]
    [string]$AdminPassword,

    [Parameter(Mandatory)]
    [string]$SafeModePassword,

    [Parameter()]
    [string]$TestUserName = 'maesterreader',

    [Parameter(Mandatory)]
    [string]$TestUserPassword,

    [Parameter()]
    [string]$DomainJoinUserName,

    [Parameter()]
    [string]$DomainJoinUserPassword,

    [Parameter()]
    [string]$KeyVaultName,

    [Parameter()]
    [string[]]$Tag = @(),

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [int]$RetryIntervalSeconds = 30,

    [Parameter()]
    [int]$CompletionTimeoutMinutes = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-LabAzCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter()]
        [switch]$ExpectJson,

        [Parameter()]
        [switch]$AllowFailure
    )

    $azCommand = Get-Command -Name 'az' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $azCommand) {
        throw 'Azure CLI (az) is required but was not found in PATH.'
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $azCommand.Source
    $psi.Arguments = ($Arguments | ForEach-Object {
        if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
    }) -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $output = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    if ($exitCode -ne 0 -and $AllowFailure.IsPresent) {
        return $null
    }

    if ($exitCode -ne 0 -and -not $AllowFailure.IsPresent) {
        $redactedArguments = @($Arguments)
        $sensitiveValues = [System.Collections.Generic.List[string]]::new()
        for ($index = 0; $index -lt $redactedArguments.Count; $index++) {
            if ($index -gt 0 -and $redactedArguments[$index - 1] -match '(?i)^--(admin-password|password|value)$') {
                $sensitiveValues.Add($redactedArguments[$index])
                $redactedArguments[$index] = '[REDACTED]'
            } elseif ($redactedArguments[$index] -match '(?i)^(?<name>[^=]*(password|secret|token)[^=]*)=(?<value>.+)$') {
                $sensitiveValues.Add($Matches.value)
                $redactedArguments[$index] = $Matches.name + '=[REDACTED]'
            }
        }
        foreach ($sensitiveValue in $sensitiveValues) {
            $output = $output.Replace($sensitiveValue, '[REDACTED]')
        }
        throw "Azure CLI command failed ($exitCode): az $($redactedArguments -join ' ')`n$output"
    }

    if ($ExpectJson.IsPresent -and $output) {
        return $output | ConvertFrom-Json
    }

    return $output
}

function Invoke-LabVmRunCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandId,

        [Parameter(Mandatory)]
        [string]$ScriptContent,

        [Parameter()]
        [hashtable]$Parameter = @{},

        [Parameter()]
        [hashtable]$ProtectedParameter = @{}
    )

    $temporaryFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $temporaryFile -Value $ScriptContent -Encoding utf8

        $arguments = @(
            'vm', 'run-command', 'invoke',
            '--resource-group', $ResourceGroupName,
            '--name', $VmName,
            '--command-id', $CommandId,
            '--scripts', ('@{0}' -f $temporaryFile),
            '--query', 'value[0].message',
            '--output', 'tsv'
        )

        if ($ProtectedParameter.Count -gt 0) {
            foreach ($key in $ProtectedParameter.Keys) {
                $Parameter[$key] = $ProtectedParameter[$key]
            }
        }

        if ($Parameter.Count -gt 0) {
            $arguments += '--parameters'
            foreach ($key in $Parameter.Keys) {
                $arguments += ('{0}={1}' -f $key, $Parameter[$key])
            }
        }

        return Invoke-LabAzCli -Arguments $arguments
    } finally {
        Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
    }
}

function Wait-LabCompletionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$TimeoutMinutes,

        [Parameter(Mandatory)]
        [int]$RetrySeconds
    )

    $deadline = (Get-Date).ToUniversalTime().AddMinutes($TimeoutMinutes)
    $probeScript = @'
if (-not (Test-Path -LiteralPath 'C:\MaesterLab\completed.json')) {
    throw 'Domain controller configuration is still in progress.'
}

Get-Content -LiteralPath 'C:\MaesterLab\completed.json' -Raw
'@

    while ((Get-Date).ToUniversalTime() -lt $deadline) {
        Start-Sleep -Seconds $RetrySeconds

        $powerState = Invoke-LabAzCli -Arguments @(
            'vm', 'get-instance-view',
            '--resource-group', $ResourceGroupName,
            '--name', $VmName,
            '--query', "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus | [0]",
            '--output', 'tsv'
        )

        if ($powerState -notmatch 'running') {
            continue
        }

        try {
            $completionMessage = Invoke-LabVmRunCommand -CommandId 'RunPowerShellScript' -ScriptContent $probeScript
            if (-not [string]::IsNullOrWhiteSpace($completionMessage)) {
                return $completionMessage
            }

            Write-Verbose "Domain controller '$VmName' has not produced a completion payload yet."
        } catch {
            Write-Verbose "Domain controller '$VmName' is not ready yet: $($_.Exception.Message)"
        }
    }

    throw "Timed out waiting for domain controller '$VmName' to finish provisioning."
}

$configureWinRmPath = Join-Path -Path $PSScriptRoot -ChildPath 'Configure-WinRM.ps1'
$winRmScriptText = & $configureWinRmPath -ListenerDnsName $VmName -EmitScript
$winRmScriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($winRmScriptText))

$nicName = '{0}-nic' -f $VmName
$existingNic = Invoke-LabAzCli -Arguments @(
    'network', 'nic', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $nicName,
    '--output', 'json'
) -AllowFailure -ExpectJson

if (-not $existingNic -and $PSCmdlet.ShouldProcess($nicName, 'Create network interface for domain controller')) {
    $nicArguments = @(
        'network', 'nic', 'create',
        '--resource-group', $ResourceGroupName,
        '--location', $Location,
        '--name', $nicName,
        '--vnet-name', $VNetName,
        '--subnet', $SubnetName,
        '--private-ip-address', $PrivateIpAddress,
        '--ip-forwarding', 'false',
        '--tags'
    ) + $Tag + @('--output', 'none')

    Invoke-LabAzCli -Arguments $nicArguments | Out-Null
}

if ($ParentDnsServer) {
    Invoke-LabAzCli -Arguments @(
        'network', 'nic', 'update',
        '--resource-group', $ResourceGroupName,
        '--name', $nicName,
        '--dns-servers', $ParentDnsServer,
        '--output', 'none'
    ) | Out-Null
}

$existingVm = Invoke-LabAzCli -Arguments @(
    'vm', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $VmName,
    '--output', 'json'
) -AllowFailure -ExpectJson

if ($existingVm) {
    if (-not $Force.IsPresent -and $existingVm.hardwareProfile.vmSize -ne 'Standard_D4s_v5') {
        throw "VM '$VmName' already exists with an unexpected size. Use -Force to take responsibility for the mismatch."
    }
} elseif ($PSCmdlet.ShouldProcess($VmName, 'Create Windows domain controller VM')) {
    $createVmArguments = @(
        'vm', 'create',
        '--resource-group', $ResourceGroupName,
        '--location', $Location,
        '--name', $VmName,
        '--image', 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest',
        '--size', 'Standard_D4s_v5',
        '--nics', $nicName,
        '--admin-username', $AdminUsername,
        '--admin-password', $AdminPassword,
        '--authentication-type', 'password',
        '--tags'
    ) + $Tag + @('--output', 'none')

    Invoke-LabAzCli -Arguments $createVmArguments | Out-Null
}

$bootstrapScript = @'
param(
    [string]$DomainRole,
    [string]$DomainName,
    [string]$DomainNetbiosName,
    [string]$VmName,
    [string]$PrivateIpAddress,
    [string]$ParentDomainName,
    [string]$ParentDnsServer,
    [string]$PromotionUserName,
    [string]$WinRmScriptBase64,
    [string]$TestUserName,
    [string]$TestUserPassword,
    [string]$SafeModePassword,
    [string]$PromotionPassword
    ,
    [string]$DomainJoinUserName,
    [string]$DomainJoinUserPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$labRoot = 'C:\MaesterLab'
$certificateDirectory = Join-Path -Path $labRoot -ChildPath 'Certificates'
$null = New-Item -Path $labRoot -ItemType Directory -Force
$null = New-Item -Path $certificateDirectory -ItemType Directory -Force

$configuration = [ordered]@{
    DomainRole         = $DomainRole
    DomainName         = $DomainName
    DomainNetbiosName  = $DomainNetbiosName
    VmName             = $VmName
    PrivateIpAddress   = $PrivateIpAddress
    ParentDomainName   = $ParentDomainName
    ParentDnsServer    = $ParentDnsServer
    PromotionUserName  = $PromotionUserName
    WinRmScriptBase64  = $WinRmScriptBase64
    TestUserName       = $TestUserName
    TestUserPassword   = $TestUserPassword
    SafeModePassword   = $SafeModePassword
    PromotionPassword  = $PromotionPassword
    DomainJoinUserName = $DomainJoinUserName
    DomainJoinUserPassword = $DomainJoinUserPassword
}

$configuration | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path -Path $labRoot -ChildPath 'config.json') -Encoding utf8

$finalizeScript = {
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$labRoot = 'C:\MaesterLab'
$configuration = Get-Content -LiteralPath (Join-Path -Path $labRoot -ChildPath 'config.json') -Raw | ConvertFrom-Json
$promotionMarker = Join-Path -Path $labRoot -ChildPath 'promotion-complete.marker'
$completionPath = Join-Path -Path $labRoot -ChildPath 'completed.json'

function Set-LabDnsClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ServerAddress
    )

    $adapter = Get-NetAdapter |
        Where-Object { $_.Status -eq 'Up' } |
        Sort-Object ifIndex |
        Select-Object -First 1

    if ($adapter) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $ServerAddress
    }
}

function New-LabLdapsCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$DnsName
    )

    $certificate = Get-ChildItem -Path Cert:\LocalMachine\My |
        Where-Object { $_.FriendlyName -eq 'Maester Lab LDAPS' } |
        Select-Object -First 1

    if ($certificate -and @($DnsName | Where-Object { $certificate.DnsNameList.Unicode -notcontains $_ }).Count -gt 0) {
        Remove-Item -LiteralPath $certificate.PSPath -Force
        $certificate = $null
    }

    if (-not $certificate) {
        $certificateParameters = @{
            DnsName           = $DnsName
            CertStoreLocation = 'Cert:\LocalMachine\My'
            FriendlyName      = 'Maester Lab LDAPS'
            KeyAlgorithm      = 'RSA'
            KeyLength         = 2048
            KeySpec           = 'KeyExchange'
            HashAlgorithm     = 'SHA256'
            TextExtension     = @('2.5.29.37={text}1.3.6.1.5.5.7.3.1')
            NotAfter          = (Get-Date).AddDays(14)
        }

        $certificate = New-SelfSignedCertificate @certificateParameters
    }

    $certificatePath = Join-Path -Path (Join-Path -Path $labRoot -ChildPath 'Certificates') -ChildPath 'ldaps.cer'
    Export-Certificate -Cert $certificate -FilePath $certificatePath -Force | Out-Null
    return $certificatePath
}

function Set-LabReaderAccount {
    [CmdletBinding()]
    param()

    Import-Module ActiveDirectory
    $testUserPassword = ConvertTo-SecureString -String $configuration.TestUserPassword -AsPlainText -Force
    $domain = Get-ADDomain -Identity $configuration.DomainName
    $userPath = 'CN=Users,' + $domain.DistinguishedName
    $existingUser = Get-ADUser -Filter "SamAccountName -eq '$($configuration.TestUserName)'" -SearchBase $userPath -ErrorAction SilentlyContinue

    if (-not $existingUser) {
        $newUserParameters = @{
            Name               = $configuration.TestUserName
            SamAccountName     = $configuration.TestUserName
            UserPrincipalName  = ($configuration.TestUserName + '@' + $configuration.DomainName)
            Path               = $userPath
            AccountPassword    = $testUserPassword
            Enabled            = $true
            PasswordNeverExpires = $true
        }

        New-ADUser @newUserParameters | Out-Null
    }

    foreach ($groupName in @('Remote Management Users', 'Event Log Readers', 'Distributed COM Users', 'Performance Log Users')) {
        $group = Get-ADGroup -Identity $groupName -ErrorAction SilentlyContinue
        if ($group) {
            Add-ADGroupMember -Identity $group.DistinguishedName -Members $configuration.TestUserName -ErrorAction SilentlyContinue
        }
    }
}

function Set-LabDomainJoinAccount {
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrWhiteSpace($configuration.DomainJoinUserName)) {
        return
    }

    Import-Module ActiveDirectory
    $joinPassword = ConvertTo-SecureString -String $configuration.DomainJoinUserPassword -AsPlainText -Force
    $domain = Get-ADDomain -Identity $configuration.DomainName
    $userPath = 'CN=Users,' + $domain.DistinguishedName
    $joinUser = Get-ADUser -Filter "SamAccountName -eq '$($configuration.DomainJoinUserName)'" -SearchBase $userPath -ErrorAction SilentlyContinue
    if (-not $joinUser) {
        New-ADUser -Name $configuration.DomainJoinUserName `
            -SamAccountName $configuration.DomainJoinUserName `
            -UserPrincipalName ($configuration.DomainJoinUserName + '@' + $configuration.DomainName) `
            -Path $userPath -AccountPassword $joinPassword -Enabled $true -PasswordNeverExpires $true
    }
}

Import-Module ServerManager
if (-not (Get-WindowsFeature -Name AD-Domain-Services).Installed) {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
}

if (-not (Test-Path -LiteralPath $promotionMarker)) {
    Import-Module ADDSDeployment
    $safeModePassword = ConvertTo-SecureString -String $configuration.SafeModePassword -AsPlainText -Force

    switch ($configuration.DomainRole) {
        'RootForest' {
            $forestParameters = @{
                DomainName                    = $configuration.DomainName
                DomainNetbiosName             = $configuration.DomainNetbiosName
                InstallDns                    = $true
                SafeModeAdministratorPassword = $safeModePassword
                Force                         = $true
                NoRebootOnCompletion          = $true
            }

            Install-ADDSForest @forestParameters
        }
        'SeparateForest' {
            $separateForestParameters = @{
                DomainName                    = $configuration.DomainName
                DomainNetbiosName             = $configuration.DomainNetbiosName
                InstallDns                    = $true
                SafeModeAdministratorPassword = $safeModePassword
                Force                         = $true
                NoRebootOnCompletion          = $true
            }

            Install-ADDSForest @separateForestParameters
        }
        'ChildDomain' {
            $promotionPassword = ConvertTo-SecureString -String $configuration.PromotionPassword -AsPlainText -Force
            $credential = [System.Management.Automation.PSCredential]::new($configuration.PromotionUserName, $promotionPassword)

            if ($configuration.ParentDnsServer) {
                Set-LabDnsClient -ServerAddress @($configuration.ParentDnsServer)
            }

            for ($attempt = 1; $attempt -le 40; $attempt++) {
                if (Resolve-DnsName -Name $configuration.ParentDomainName -Server $configuration.ParentDnsServer -ErrorAction SilentlyContinue) {
                    break
                }

                Start-Sleep -Seconds 15
            }


            $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
            if (-not $computerSystem.PartOfDomain) {
                Add-Computer -DomainName $configuration.ParentDomainName -Credential $credential -Force
                Restart-Computer -Force
                return
            }

            if ($computerSystem.Domain -ne $configuration.ParentDomainName) {
                throw "Child domain controller is joined to '$($computerSystem.Domain)', expected '$($configuration.ParentDomainName)'."
            }

            $childDomainParameters = @{
                ParentDomainName              = $configuration.ParentDomainName
                NewDomainName                 = (($configuration.DomainName -split '\.')[0])
                DomainType                    = 'ChildDomain'
                InstallDns                    = $true
                Credential                    = $credential
                SafeModeAdministratorPassword = $safeModePassword
                Force                         = $true
                NoRebootOnCompletion          = $true
            }

            Install-ADDSDomain @childDomainParameters
        }
    }

    Set-Content -LiteralPath $promotionMarker -Value (Get-Date).ToString('o') -Encoding utf8
    Restart-Computer -Force
    return
}

# Post-reboot configuration
$errors = [System.Collections.Generic.List[string]]::new()

# Wait for AD services to be ready
$adReady = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $null = Get-ADRootDSE -ErrorAction Stop
        $adReady = $true
        break
    } catch {
        Start-Sleep -Seconds 10
    }
}

if (-not $adReady) {
    $errors.Add('Active Directory services did not become ready after reboot.')
}

$dnsServers = @($configuration.PrivateIpAddress)
if ($configuration.ParentDnsServer) {
    $dnsServers += $configuration.ParentDnsServer
}

try {
    Set-LabDnsClient -ServerAddress $dnsServers
} catch {
    $errors.Add("Failed to set DNS client: $($_.Exception.Message)")
}

$certificatePath = $null
try {
    $certificatePath = New-LabLdapsCertificate -DnsName @($env:COMPUTERNAME, ($env:COMPUTERNAME + '.' + $configuration.DomainName), $configuration.DomainName)
    Restart-Service -Name NTDS -Force -ErrorAction Stop
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        try {
            $null = Get-ADRootDSE -ErrorAction Stop
            break
        } catch {
            if ($attempt -eq 30) { throw }
            Start-Sleep -Seconds 5
        }
    }
} catch {
    $errors.Add("Failed to create LDAPS certificate: $($_.Exception.Message)")
}

try {
    [scriptblock]::Create([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($configuration.WinRmScriptBase64))).Invoke() | Out-Null
} catch {
    $errors.Add("Failed to configure WinRM: $($_.Exception.Message)")
}

try {
    Set-LabReaderAccount
} catch {
    $errors.Add("Failed to set reader account: $($_.Exception.Message)")
}

try {
    Set-LabDomainJoinAccount
} catch {
    $errors.Add("Failed to create delegated domain-join account: $($_.Exception.Message)")
}

$result = [ordered]@{
    VmName                 = $env:COMPUTERNAME
    DomainName             = $configuration.DomainName
    LdapsCertificateBase64 = if ($certificatePath) { [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($certificatePath)) } else { $null }
    TestCredentialUser     = ($configuration.DomainNetbiosName + '\' + $configuration.TestUserName)
    CompletionTimeUtc      = (Get-Date).ToUniversalTime().ToString('o')
    Errors                 = $errors.ToArray()
    Success                = ($errors.Count -eq 0)
}

$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $completionPath -Encoding utf8
Unregister-ScheduledTask -TaskName 'MaesterLab-DomainControllerFinalize' -Confirm:$false -ErrorAction SilentlyContinue
}.ToString()

$finalizeScript | Set-Content -LiteralPath (Join-Path -Path $labRoot -ChildPath 'finalize.ps1') -Encoding utf8

$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\MaesterLab\finalize.ps1'
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
Unregister-ScheduledTask -TaskName 'MaesterLab-DomainControllerFinalize' -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName 'MaesterLab-DomainControllerFinalize' -InputObject $task -Force | Out-Null
Start-ScheduledTask -TaskName 'MaesterLab-DomainControllerFinalize'
'@

$bootstrapResult = Invoke-LabVmRunCommand -CommandId 'RunPowerShellScript' -ScriptContent $bootstrapScript -Parameter @{
        DomainRole        = $DomainRole
        DomainName        = $DomainName
        DomainNetbiosName = $DomainNetbiosName
        VmName            = $VmName
        PrivateIpAddress  = $PrivateIpAddress
        ParentDomainName  = $(if ($ParentDomainName) { $ParentDomainName } else { '' })
        ParentDnsServer   = $(if ($ParentDnsServer) { $ParentDnsServer } else { '' })
        PromotionUserName = $(if ($PromotionUserName) { $PromotionUserName } else { '' })
        WinRmScriptBase64 = $winRmScriptBase64
        TestUserName      = $TestUserName
        DomainJoinUserName = $(if ($DomainJoinUserName) { $DomainJoinUserName } else { '' })
    } -ProtectedParameter @{
        TestUserPassword  = $TestUserPassword
        SafeModePassword  = $SafeModePassword
        PromotionPassword = $(if ($PromotionPassword) { $PromotionPassword } else { $AdminPassword })
        DomainJoinUserPassword = $(if ($DomainJoinUserPassword) { $DomainJoinUserPassword } else { '' })
    }

Write-Verbose $bootstrapResult

$completionMessage = Wait-LabCompletionFile -TimeoutMinutes $CompletionTimeoutMinutes -RetrySeconds $RetryIntervalSeconds
$completion = $completionMessage | ConvertFrom-Json

$completionPropertyNames = @()
if ($null -ne $completion) {
    $completionPropertyNames = @($completion.PSObject.Properties.Name)
}

$completionErrors = @()
if ($completionPropertyNames -contains 'Errors' -and $null -ne $completion.Errors) {
    $completionErrors = @($completion.Errors)
}

$completionSucceeded = $false
if ($completionPropertyNames -contains 'Success') {
    $completionSucceeded = [bool]$completion.Success
}

if ($completionErrors.Count -gt 0) {
    Write-Warning "Domain controller '$VmName' completed with errors:"
    foreach ($err in $completionErrors) {
        Write-Warning "  $err"
    }
}

if (-not $completionSucceeded) {
    throw "Domain controller '$VmName' provisioning failed. Errors: $($completionErrors -join '; ')"
}

if ($KeyVaultName -and $completion.LdapsCertificateBase64) {
    Invoke-LabAzCli -Arguments @(
        'keyvault', 'secret', 'set',
        '--vault-name', $KeyVaultName,
        '--name', ('{0}-{1}-ldaps-cert' -f ($VmName.ToLowerInvariant()), ($DomainName.ToLowerInvariant() -replace '[^a-z0-9-]', '-')),
        '--value', $completion.LdapsCertificateBase64,
        '--output', 'none'
    ) | Out-Null
}

[PSCustomObject]@{
    VmName                 = $VmName
    PrivateIpAddress       = $PrivateIpAddress
    DomainRole             = $DomainRole
    DomainName             = $DomainName
    LdapsCertificateBase64 = $completion.LdapsCertificateBase64
    TestCredentialUser     = $completion.TestCredentialUser
    Success                = $completionSucceeded
    Errors                 = $completionErrors
}
