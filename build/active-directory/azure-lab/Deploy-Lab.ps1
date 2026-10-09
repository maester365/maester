<#
.SYNOPSIS
    Deploys the Maester multi-platform, multi-forest Azure lab.

.DESCRIPTION
    Orchestrates the Azure network, three domain controllers, and two runner VMs
    used for Maester end-to-end Active Directory validation. The script is
    designed to be idempotent, tags every resource for cost tracking and
    collision avoidance, generates ephemeral credentials at runtime, stores them
    in Azure Key Vault unless SkipKeyVault is specified, and tears the lab back
    down automatically when a deployment step fails.

    The deployed topology is read from LabConfig.json. A typical multi-forest
    layout includes a root forest DC, a child domain DC, a separate-forest DC,
    a Windows runner, and a Linux runner. The root and child domains share an
    automatic two-way transitive intra-forest trust. No trust is configured
    between separate forests. Each domain controller issues an LDAPS/StartTLS
    certificate that is trusted by both runners.

    The runners are intentionally configured without the ActiveDirectory,
    GroupPolicy, or DnsServer PowerShell modules.

.PARAMETER ResourceGroupName
    Existing Azure resource group that will host the lab.

.PARAMETER Location
    Azure region for all resources.

.PARAMETER ExecutorPublicIp
    Public IP address of the operator workstation. If omitted, the script tries
    to discover it and locks the NSG rules down to that address.

.PARAMETER LabId
    Unique lab identifier used in tags, collision checks, and cleanup.

.PARAMETER KeyVaultName
    Optional Key Vault name. If omitted, a short deterministic vault name is
    generated from the lab ID.

.PARAMETER SkipKeyVault
    Skip Key Vault creation and instead print the generated secret material at
    the end of the run. This is less secure and should only be used for short-
    lived test subscriptions.

.PARAMETER ExpiresOnUtc
    Expiration tag value for automatic cost cleanup.

.PARAMETER CleanupOnFailure
    Remove tagged resources if deployment fails after partial creation.

.PARAMETER SkipValidation
    Skip the post-deployment validation script.

.EXAMPLE
    ./build/active-directory/azure-lab/Deploy-Lab.ps1 -ExecutorPublicIp 203.0.113.10

    Deploys the full lab and stores generated credentials in an ephemeral Key
    Vault.

.EXAMPLE
    ./build/active-directory/azure-lab/Deploy-Lab.ps1 -ExecutorPublicIp 203.0.113.10 -WhatIf

    Shows the main orchestration flow without creating Azure resources.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions',
    'Set-LabSecret',
    Justification = 'The helper is only invoked from script-level ShouldProcess gates.'
)]
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ResourceGroupName,

    [Parameter()]
    [string]$Location,

    [Parameter()]
    [string]$ExecutorPublicIp,

    [Parameter()]
    [string]$LabId,

    [Parameter()]
    [string]$KeyVaultName,

    [Parameter()]
    [switch]$SkipKeyVault,

    [Parameter()]
    [datetime]$ExpiresOnUtc = (Get-Date).ToUniversalTime().AddHours(12),

    [Parameter()]
    [string]$OwnerTag = $env:USER,

    [Parameter()]
    [string]$CostCenterTag,

    [Parameter()]
    [string]$AdminUsername,

    [Parameter()]
    [string]$TestUserName,

    [Parameter()]
    [string]$DomainJoinUserName,

    [Parameter()]
    [string]$LabConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'LabConfig.json'),

    [Parameter()]
    [bool]$CleanupOnFailure = $true,

    [Parameter()]
    [switch]$SkipValidation,

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScriptRoot = $PSScriptRoot

if (-not (Test-Path -LiteralPath $LabConfigPath)) {
    throw "Lab configuration file not found: $LabConfigPath. Copy LabConfig.template.json to LabConfig.json and fill in your deployment-specific values."
}

$labConfig = Get-Content -LiteralPath $LabConfigPath -Raw | ConvertFrom-Json

if (-not $ResourceGroupName) { $ResourceGroupName = $labConfig.deployment.resourceGroupName }
if (-not $Location) { $Location = $labConfig.deployment.location }
if (-not $LabId) { $LabId = ('{0}-lab-{1}' -f $labConfig.deployment.labPrefix, (Get-Date -Format 'yyyyMMddHHmmss')) }
if (-not $CostCenterTag) { $CostCenterTag = $labConfig.deployment.costCenterTag }
if (-not $AdminUsername) { $AdminUsername = $labConfig.credentials.localAdminUsername }
if (-not $TestUserName) { $TestUserName = $labConfig.credentials.testUserName }
if (-not $DomainJoinUserName) { $DomainJoinUserName = $labConfig.credentials.domainJoinUserName }

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

function Get-LabExecutorIpAddress {
    [CmdletBinding()]
    param()

    if ($ExecutorPublicIp) {
        return $ExecutorPublicIp
    }

    try {
        return (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10).ToString().Trim()
    } catch {
        throw 'ExecutorPublicIp was not supplied and automatic public IP discovery failed.'
    }
}

function ConvertTo-LabKeyVaultName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Seed
    )

    $normalized = $Seed.ToLowerInvariant() -replace '[^a-z0-9-]', ''
    $normalized = $normalized.Trim('-')
    if ($normalized.Length -gt 20) {
        $normalized = $normalized.Substring(0, 20)
    }

    return ('kv{0}' -f $normalized)
}

function Get-LabRandomPassword {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Length = 28
    )

    $lower = 'abcdefghijkmnopqrstuvwxyz'
    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $digits = '23456789'
    $symbols = '!@$%*-_=+?'
    $allCharacters = ($lower + $upper + $digits + $symbols).ToCharArray()

    $passwordCharacters = [System.Collections.Generic.List[char]]::new()
    $passwordCharacters.Add($lower[(Get-Random -Minimum 0 -Maximum $lower.Length)])
    $passwordCharacters.Add($upper[(Get-Random -Minimum 0 -Maximum $upper.Length)])
    $passwordCharacters.Add($digits[(Get-Random -Minimum 0 -Maximum $digits.Length)])
    $passwordCharacters.Add($symbols[(Get-Random -Minimum 0 -Maximum $symbols.Length)])

    while ($passwordCharacters.Count -lt $Length) {
        $passwordCharacters.Add($allCharacters[(Get-Random -Minimum 0 -Maximum $allCharacters.Length)])
    }

    return (-join ($passwordCharacters | Sort-Object { Get-Random }))
}

function Set-LabSecret {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$VaultName,

        [Parameter(Mandatory)]
        [string]$SecretName,

        [Parameter(Mandatory)]
        [string]$SecretValue,

        [Parameter()]
        [string[]]$Tag = @()
    )

    $secretArguments = @(
        'keyvault', 'secret', 'set',
        '--vault-name', $VaultName,
        '--name', $SecretName,
        '--value', $SecretValue,
        '--output', 'none'
    )

    if ($Tag.Count -gt 0) {
        $secretArguments += '--tags'
        $secretArguments += $Tag
    }

    if ($PSCmdlet.ShouldProcess($SecretName, 'Persist generated secret in Azure Key Vault')) {
        Invoke-LabAzCli -Arguments $secretArguments | Out-Null
    }
}

function Invoke-LabVmRunCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VmName,

        [Parameter(Mandatory)]
        [string]$ScriptContent
    )

    $temporaryFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $temporaryFile -Value $ScriptContent -Encoding utf8
        Invoke-LabAzCli -Arguments @(
            'vm', 'run-command', 'invoke',
            '--resource-group', $ResourceGroupName,
            '--name', $VmName,
            '--command-id', 'RunPowerShellScript',
            '--scripts', ('@{0}' -f $temporaryFile),
            '--query', 'value[0].message',
            '--output', 'tsv'
        )
    } finally {
        Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
    }
}

$newLabVnetPath = Join-Path -Path $script:ScriptRoot -ChildPath 'New-LabVNet.ps1'
$newDomainControllerPath = Join-Path -Path $script:ScriptRoot -ChildPath 'New-DomainController.ps1'
$newRunnerVmPath = Join-Path -Path $script:ScriptRoot -ChildPath 'New-RunnerVm.ps1'
$testLabPrerequisitesPath = Join-Path -Path $script:ScriptRoot -ChildPath 'Test-LabPrerequisites.ps1'
$removeLabPath = Join-Path -Path $script:ScriptRoot -ChildPath 'Remove-Lab.ps1'

$labTopology = [ordered]@{
    ResourceGroupName = $ResourceGroupName
    Location          = $Location
    VNetName          = $labConfig.network.vnetName
    AddressPrefix     = $labConfig.network.vnetAddressSpace
    SubnetName        = $labConfig.network.subnetName
    NsgName           = $labConfig.network.nsgName
    DomainControllers = @()
    Runners           = @()
}

foreach ($dc in $labConfig.domainControllers) {
    $labTopology.DomainControllers += [ordered]@{
        Name          = $dc.azureVmName
        Role          = $dc.role
        DomainName    = $dc.domain
        ChildName     = $dc.childName
        NetBios       = $dc.netBiosName
        PrivateIp     = $dc.privateIp
        ParentDomain  = $dc.parentDomain
        ParentDns     = $dc.parentDnsIp
        PromotionUser = $dc.promotionUser
    }
}

foreach ($runner in $labConfig.runners) {
    $labTopology.Runners += [ordered]@{
        Name           = $runner.azureVmName
        ComputerName   = $runner.computerName
        OsType         = $runner.osType
        PrivateIp      = $runner.privateIp
        DomainName     = $runner.domain
        DomainJoinUser = $runner.domainJoinUser
    }
}

if ($ExpiresOnUtc -gt (Get-Date).ToUniversalTime().AddDays(7)) {
    throw 'ExpiresOnUtc must be within seven days to keep the lab ephemeral.'
}

$executorPublicIp = Get-LabExecutorIpAddress
$executorCidr = if ($executorPublicIp.Contains('/')) { $executorPublicIp } else { '{0}/32' -f $executorPublicIp }

$tags = @(
    'maester-scenario=azure-ad-e2e-lab',
    'maester-plan=04-task-18',
    ('maester-lab-id={0}' -f $LabId),
    ('maester-owner={0}' -f $(if ($OwnerTag) { $OwnerTag } else { 'unknown' })),
    ('maester-expiry-utc={0}' -f $ExpiresOnUtc.ToString('o')),
    ('maester-cost-center={0}' -f $CostCenterTag)
)

$credentialBundle = [ordered]@{
    WindowsLocalAdminPassword       = Get-LabRandomPassword
    WindowsRunnerLocalAdminPassword = Get-LabRandomPassword
    LinuxLocalAdminPassword         = Get-LabRandomPassword
    RootDomainJoinPassword          = Get-LabRandomPassword
}

foreach ($dc in $labTopology.DomainControllers) {
    if ($dc.Role -eq 'ChildDomain' -and $dc.ParentDomain) {
        $parentDc = $labTopology.DomainControllers | Where-Object { $_.Role -eq 'RootForest' -and $_.DomainName -eq $dc.ParentDomain } | Select-Object -First 1
        if ($parentDc -and $credentialBundle.Contains(('{0}SafeModePassword' -f $parentDc.Name))) {
            $credentialBundle[('{0}SafeModePassword' -f $dc.Name)] = $credentialBundle[('{0}SafeModePassword' -f $parentDc.Name)]
        } else {
            $credentialBundle[('{0}SafeModePassword' -f $dc.Name)] = Get-LabRandomPassword
        }
    } else {
        $credentialBundle[('{0}SafeModePassword' -f $dc.Name)] = Get-LabRandomPassword
    }
    $credentialBundle[('{0}ReaderPassword' -f $dc.Name)] = Get-LabRandomPassword
}

$summary = [ordered]@{
    LabId                = $LabId
    ResourceGroupName    = $ResourceGroupName
    Location             = $Location
    ExecutorPublicIp     = $executorCidr
    KeyVaultName         = $null
    DomainControllerInfo = @()
    RunnerInfo           = @()
    SecretNames          = @()
}

try {
    $useVerbose = $VerbosePreference -eq 'Continue'
    Write-Verbose "Validating Azure access for resource group '$ResourceGroupName'."
    Invoke-LabAzCli -Arguments @('account', 'show', '--output', 'none') | Out-Null

    $resourceGroup = Invoke-LabAzCli -Arguments @('group', 'show', '--name', $ResourceGroupName, '--output', 'json') -ExpectJson
    if ($resourceGroup.location -ne $Location) {
        throw "Resource group '$ResourceGroupName' exists in '$($resourceGroup.location)', not '$Location'."
    }

    if (-not $SkipKeyVault.IsPresent) {
        $effectiveKeyVaultName = if ($KeyVaultName) { $KeyVaultName } else { ConvertTo-LabKeyVaultName -Seed $LabId }
        $summary.KeyVaultName = $effectiveKeyVaultName

        $existingVault = Invoke-LabAzCli -Arguments @('keyvault', 'show', '--name', $effectiveKeyVaultName, '--resource-group', $ResourceGroupName, '--output', 'json') -AllowFailure -ExpectJson
        if (-not $existingVault) {
            if ($PSCmdlet.ShouldProcess($effectiveKeyVaultName, 'Create Azure Key Vault')) {
                Write-Verbose "About to create Key Vault with tags: $($tags -join ', ')"
                $kvArgs = @(
                    'keyvault', 'create',
                    '--name', $effectiveKeyVaultName,
                    '--resource-group', $ResourceGroupName,
                    '--location', $Location,
                    '--enable-rbac-authorization', 'true',
                    '--enabled-for-template-deployment', 'true',
                    '--retention-days', '7',
                    '--sku', 'standard',
                    '--tags'
                ) + $tags
                Write-Verbose "KV args count: $($kvArgs.Count)"
                Invoke-LabAzCli -Arguments $kvArgs | Out-Null
            }
        }

        foreach ($credentialName in $credentialBundle.Keys) {
            $secretName = ('{0}-{1}' -f $LabId, $credentialName).ToLowerInvariant()
            $summary.SecretNames += $secretName
            if ($PSCmdlet.ShouldProcess($secretName, 'Store generated secret in Azure Key Vault')) {
                Set-LabSecret -VaultName $effectiveKeyVaultName -SecretName $secretName -SecretValue $credentialBundle[$credentialName] -Tag $tags
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($labTopology.VNetName, 'Provision Azure virtual network and NSG')) {
        $newLabVNetParameters = @{
            ResourceGroupName = $ResourceGroupName
            Location          = $Location
            VNetName          = $labTopology.VNetName
            AddressPrefix     = $labTopology.AddressPrefix
            SubnetName        = $labTopology.SubnetName
            SubnetPrefix      = $labTopology.AddressPrefix
            NsgName           = $labTopology.NsgName
            ExecutorPublicIp  = $executorCidr
            Tag               = $tags
            Force             = $Force.IsPresent
            Verbose           = $useVerbose
        }

        & $newLabVnetPath @newLabVNetParameters
    }

    $domainCertificates = [System.Collections.Generic.List[string]]::new()

    $rootController = $labTopology.DomainControllers[0]
    $rootDomainControllerParameters = @{
        ResourceGroupName = $ResourceGroupName
        Location          = $Location
        VNetName          = $labTopology.VNetName
        SubnetName        = $labTopology.SubnetName
        VmName            = $rootController.Name
        PrivateIpAddress  = $rootController.PrivateIp
        DomainRole        = $rootController.Role
        DomainName        = $rootController.DomainName
        DomainNetbiosName = $rootController.NetBios
        AdminUsername     = $AdminUsername
        AdminPassword     = $credentialBundle.WindowsLocalAdminPassword
        SafeModePassword  = $credentialBundle[('{0}SafeModePassword' -f $rootController.Name)]
        TestUserName      = $TestUserName
        TestUserPassword  = $credentialBundle[('{0}ReaderPassword' -f $rootController.Name)]
        DomainJoinUserName = $DomainJoinUserName
        DomainJoinUserPassword = $credentialBundle.RootDomainJoinPassword
        KeyVaultName      = $summary.KeyVaultName
        Tag               = $tags
        Force             = $Force.IsPresent
        Verbose           = $useVerbose
    }

    if ($PSCmdlet.ShouldProcess($rootController.Name, 'Deploy root forest domain controller')) {
        $rootResult = & $newDomainControllerPath @rootDomainControllerParameters
        $summary.DomainControllerInfo += $rootResult
        if ($rootResult.LdapsCertificateBase64) {
            $domainCertificates.Add($rootResult.LdapsCertificateBase64)
        }
    }

    if ($PSCmdlet.ShouldProcess($labTopology.VNetName, 'Advertise DC02 as the canonical VNet DNS resolver after it is ready')) {
        Invoke-LabAzCli -Arguments @(
            'network', 'vnet', 'update',
            '--resource-group', $ResourceGroupName,
            '--name', $labTopology.VNetName,
            '--dns-servers', $rootController.PrivateIp,
            '--output', 'none'
        ) | Out-Null
    }

    $childController = $labTopology.DomainControllers[1]
    $childDomainControllerParameters = @{
        ResourceGroupName = $ResourceGroupName
        Location          = $Location
        VNetName          = $labTopology.VNetName
        SubnetName        = $labTopology.SubnetName
        VmName            = $childController.Name
        PrivateIpAddress  = $childController.PrivateIp
        DomainRole        = $childController.Role
        DomainName        = $childController.DomainName
        DomainNetbiosName = $childController.NetBios
        ParentDomainName  = $childController.ParentDomain
        ParentDnsServer   = $childController.ParentDns
        PromotionUserName = $childController.PromotionUser
        PromotionPassword = $credentialBundle.WindowsLocalAdminPassword
        AdminUsername     = $AdminUsername
        AdminPassword     = $credentialBundle.WindowsLocalAdminPassword
        SafeModePassword  = $credentialBundle[('{0}SafeModePassword' -f $childController.Name)]
        TestUserName      = $TestUserName
        TestUserPassword  = $credentialBundle[('{0}ReaderPassword' -f $childController.Name)]
        KeyVaultName      = $summary.KeyVaultName
        Tag               = $tags
        Force             = $Force.IsPresent
        Verbose           = $useVerbose
    }

    if ($PSCmdlet.ShouldProcess($childController.Name, 'Deploy child domain controller')) {
        $childResult = & $newDomainControllerPath @childDomainControllerParameters
        $summary.DomainControllerInfo += $childResult
        if ($childResult.LdapsCertificateBase64) {
            $domainCertificates.Add($childResult.LdapsCertificateBase64)
        }
    }

    $forestController = $labTopology.DomainControllers[2]
    $forestDomainControllerParameters = @{
        ResourceGroupName = $ResourceGroupName
        Location          = $Location
        VNetName          = $labTopology.VNetName
        SubnetName        = $labTopology.SubnetName
        VmName            = $forestController.Name
        PrivateIpAddress  = $forestController.PrivateIp
        DomainRole        = $forestController.Role
        DomainName        = $forestController.DomainName
        DomainNetbiosName = $forestController.NetBios
        AdminUsername     = $AdminUsername
        AdminPassword     = $credentialBundle.WindowsLocalAdminPassword
        SafeModePassword  = $credentialBundle[('{0}SafeModePassword' -f $forestController.Name)]
        TestUserName      = $TestUserName
        TestUserPassword  = $credentialBundle[('{0}ReaderPassword' -f $forestController.Name)]
        KeyVaultName      = $summary.KeyVaultName
        Tag               = $tags
        Force             = $Force.IsPresent
        Verbose           = $useVerbose
    }

    if ($PSCmdlet.ShouldProcess($forestController.Name, 'Deploy separate forest domain controller')) {
        $forestResult = & $newDomainControllerPath @forestDomainControllerParameters
        $summary.DomainControllerInfo += $forestResult
        if ($forestResult.LdapsCertificateBase64) {
            $domainCertificates.Add($forestResult.LdapsCertificateBase64)
        }
    }

    $dnsForwarderTopology = @(
        [ordered]@{
            VmName = $rootController.Name
            Zones  = @(
                [ordered]@{ Name = $forestController.DomainName; MasterServer = $forestController.PrivateIp }
            )
        },
        [ordered]@{
            VmName = $forestController.Name
            Zones  = @(
                [ordered]@{ Name = $rootController.DomainName; MasterServer = $rootController.PrivateIp }
            )
        }
    )

    foreach ($dnsHost in $dnsForwarderTopology) {
        $dnsZoneJson = $dnsHost.Zones | ConvertTo-Json -Compress
        $dnsForwarderScript = @"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Import-Module DnsServer
`$zones = '$dnsZoneJson' | ConvertFrom-Json
foreach (`$zone in @(`$zones)) {
    `$existing = Get-DnsServerConditionalForwarderZone -Name `$zone.Name -ErrorAction SilentlyContinue
    if (`$existing) {
        Set-DnsServerConditionalForwarderZone -Name `$zone.Name -MasterServers @(`$zone.MasterServer) -PassThru | Out-Null
    } else {
        Add-DnsServerConditionalForwarderZone -Name `$zone.Name -MasterServers @(`$zone.MasterServer) -ReplicationScope Forest -PassThru | Out-Null
    }
}
@(`$zones | ForEach-Object { Resolve-DnsName -Name `$_.Name -Type SOA -ErrorAction Stop }).Count
"@

        if ($PSCmdlet.ShouldProcess($dnsHost.VmName, 'Configure cross-domain and cross-forest DNS conditional forwarders')) {
            Write-Verbose (Invoke-LabVmRunCommand -VmName $dnsHost.VmName -ScriptContent $dnsForwarderScript)
        }
    }

    # The child-domain promotion creates its authoritative delegation beneath the
    # root domain. Validate that delegation and both forest forwarders before
    # creating runners that depend on the root DC for all three namespaces.
    $dnsValidationJson = $labTopology.DomainControllers | ForEach-Object {
        [ordered]@{ Name = ('{0}.{1}' -f $_.Name, $_.DomainName); ExpectedAddress = $_.PrivateIp }
    } | ConvertTo-Json -Compress
    $dnsValidationScript = @"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
`$targets = '$dnsValidationJson' | ConvertFrom-Json
foreach (`$target in @(`$targets)) {
    `$addresses = @(Resolve-DnsName -Name `$target.Name -Type A -ErrorAction Stop | Where-Object Type -eq 'A' | Select-Object -ExpandProperty IPAddress)
    if (`$addresses -notcontains `$target.ExpectedAddress) {
        throw "DNS target '`$(`$target.Name)' did not resolve to expected address '`$(`$target.ExpectedAddress)'."
    }
}
"@
    if ($PSCmdlet.ShouldProcess($rootController.Name, 'Validate runner-visible root, child, and separate-forest DNS targets')) {
        Write-Verbose (Invoke-LabVmRunCommand -VmName $rootController.Name -ScriptContent $dnsValidationScript)
    }

    if (-not $WhatIfPreference -and $domainCertificates.Count -ne $labTopology.DomainControllers.Count) {
        throw "Expected one LDAPS/StartTLS trust anchor from each domain controller; received $($domainCertificates.Count) of $($labTopology.DomainControllers.Count)."
    }

    # DC02 is the canonical resolver. Its conditional forwarders route child and
    # separate-forest names without relying on DNS-client fallback after NXDOMAIN.
    $runnerDnsServers = @($rootController.PrivateIp)

    foreach ($runner in $labTopology.Runners) {
        $runnerAdminPassword = if ($runner.OsType -eq 'Windows') {
            $credentialBundle.WindowsRunnerLocalAdminPassword
        } else {
            $credentialBundle.LinuxLocalAdminPassword
        }

        $runnerParameters = @{
            ResourceGroupName       = $ResourceGroupName
            Location                = $Location
            VNetName                = $labTopology.VNetName
            SubnetName              = $labTopology.SubnetName
            VmName                  = $runner.Name
            ComputerName            = $runner.ComputerName
            OsType                  = $runner.OsType
            PrivateIpAddress        = $runner.PrivateIp
            DnsServer               = $runnerDnsServers
            AdminUsername           = $AdminUsername
            AdminPassword           = $runnerAdminPassword
            DomainName              = $runner.DomainName
            DomainJoinUsername      = $runner.DomainJoinUser
            DomainJoinPassword      = $(if ($runner.DomainName) { $credentialBundle.RootDomainJoinPassword } else { $null })
            TrustedCertificateBase64 = $domainCertificates.ToArray()
            Tag                     = $tags
            Force                   = $Force.IsPresent
            Verbose                 = $useVerbose
        }

        if ($PSCmdlet.ShouldProcess($runner.Name, 'Deploy runner VM')) {
            $runnerResult = & $newRunnerVmPath @runnerParameters
            $summary.RunnerInfo += $runnerResult
        }
    }

    if (-not $SkipValidation.IsPresent -and $PSCmdlet.ShouldProcess('Lab validation', 'Run post-deployment validation')) {
        $validationParameters = @{
            ResourceGroupName = $ResourceGroupName
            TagName           = 'maester-lab-id'
            TagValue          = $LabId
            Verbose           = $useVerbose
        }

        & $testLabPrerequisitesPath @validationParameters
    }

    if ($SkipKeyVault.IsPresent) {
        Write-Warning 'SkipKeyVault was used. Generated secrets are printed below because no secure vault was requested.'
        [PSCustomObject]$credentialBundle
    }

    [PSCustomObject]$summary
} catch {
    Write-Error $_

    if ($CleanupOnFailure) {
        Write-Warning "Deployment failed. Starting cleanup for lab ID '$LabId'."
        & $removeLabPath -ResourceGroupName $ResourceGroupName -TagName 'maester-lab-id' -TagValue $LabId -Verbose:($VerbosePreference -eq 'Continue')
    }

    throw
}
