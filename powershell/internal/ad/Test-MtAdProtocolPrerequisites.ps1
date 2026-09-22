function Test-MtAdProtocolPrerequisites {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Matches the internal AD protocol prerequisite contract requested for this feature.')]
    [OutputType([PSCustomObject])]
    param(
        [hashtable] $RuntimeInfo,

        [Nullable[bool]] $DirectoryServicesProtocolsAvailable,

        [Nullable[bool]] $PSWSManInstalled,

        [Nullable[bool]] $SmbClientAvailable
    )

    function Get-DefaultPlatformValue {
        if ($PSVersionTable.Platform) {
            return [string]$PSVersionTable.Platform
        }

        if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
            return 'Win32NT'
        }

        return 'Unix'
    }

    function Get-RuntimeValue {
        param(
            [Parameter(Mandatory)]
            [string] $Name,

            $DefaultValue
        )

        if ($null -ne $RuntimeInfo -and $RuntimeInfo.ContainsKey($Name)) {
            return $RuntimeInfo[$Name]
        }

        return $DefaultValue
    }

    function Test-DirectoryServicesProtocolsAssembly {
        param(
            [Parameter(Mandatory)]
            [string] $RuntimePSEdition,

            [Parameter(Mandatory)]
            [string] $PlatformName
        )

        if ($PSBoundParameters.ContainsKey('DirectoryServicesProtocolsAvailable')) {
            return [bool]$DirectoryServicesProtocolsAvailable
        }

        $loadedAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GetName().Name -eq 'System.DirectoryServices.Protocols' } |
            Select-Object -First 1
        if ($null -ne $loadedAssembly) {
            return $true
        }

        $candidatePaths = [System.Collections.Generic.List[string]]::new()

        if (($RuntimePSEdition -eq 'Desktop' -or $PlatformName -eq 'Windows') -and -not [string]::IsNullOrWhiteSpace($env:windir)) {
            foreach ($gacRoot in @(
                    (Join-Path $env:windir 'Microsoft.NET/assembly/GAC_MSIL/System.DirectoryServices.Protocols'),
                    (Join-Path $env:windir 'assembly/GAC_MSIL/System.DirectoryServices.Protocols')
                )) {
                if (Test-Path -LiteralPath $gacRoot) {
                    foreach ($candidatePath in @(Get-ChildItem -LiteralPath $gacRoot -Recurse -Filter 'System.DirectoryServices.Protocols.dll' -ErrorAction SilentlyContinue |
                            ForEach-Object { $_.FullName })) {
                        $candidatePaths.Add($candidatePath)
                    }
                }
            }
        }

        foreach ($runtimePath in @(
                (Join-Path $PSHOME 'System.DirectoryServices.Protocols.dll'),
                (Join-Path $PSHOME 'ref/System.DirectoryServices.Protocols.dll')
            )) {
            if (Test-Path -LiteralPath $runtimePath) {
                $candidatePaths.Add($runtimePath)
            }
        }

        $trustedAssemblies = [System.AppContext]::GetData('TRUSTED_PLATFORM_ASSEMBLIES')
        if (-not [string]::IsNullOrWhiteSpace($trustedAssemblies)) {
            foreach ($candidatePath in @(($trustedAssemblies -split [System.IO.Path]::PathSeparator) |
                    Where-Object { [System.IO.Path]::GetFileName($_) -ieq 'System.DirectoryServices.Protocols.dll' })) {
                $candidatePaths.Add($candidatePath)
            }
        }

        return @($candidatePaths | Select-Object -Unique).Count -gt 0
    }

    $runtimePSEdition = [string](Get-RuntimeValue -Name 'PSEdition' -DefaultValue $PSVersionTable.PSEdition)
    $runtimePSVersion = [version](Get-RuntimeValue -Name 'PSVersion' -DefaultValue $PSVersionTable.PSVersion)
    $runtimePlatform = [string](Get-RuntimeValue -Name 'Platform' -DefaultValue (Get-DefaultPlatformValue))
    $runtimeIsWindows = [bool](Get-RuntimeValue -Name 'IsWindows' -DefaultValue ($IsWindows -or $runtimePSEdition -eq 'Desktop'))
    $runtimeIsLinux = [bool](Get-RuntimeValue -Name 'IsLinux' -DefaultValue $IsLinux)
    $runtimeIsMacOS = [bool](Get-RuntimeValue -Name 'IsMacOS' -DefaultValue $IsMacOS)

    $runtimeProfileName = if ($runtimeIsWindows -and $runtimePSEdition -eq 'Desktop') {
        'WindowsPS51'
    }
    elseif ($runtimeIsWindows) {
        'WindowsPS7'
    }
    elseif ($runtimeIsLinux) {
        'LinuxPS7'
    }
    elseif ($runtimeIsMacOS) {
        'MacOSPS7'
    }
    else {
        'Unknown'
    }

    $authMatrix = Get-MtAdSupportedAuthMatrix
    $runtimeProfile = $authMatrix.Profiles[$runtimeProfileName]

    $missingPrerequisites = [System.Collections.Generic.List[string]]::new()
    $remediationActions = [System.Collections.Generic.List[string]]::new()

    $ldapProtocolsAvailable = Test-DirectoryServicesProtocolsAssembly -RuntimePSEdition $runtimePSEdition -PlatformName $(if ($runtimeIsWindows) { 'Windows' } elseif ($runtimeIsLinux) { 'Linux' } elseif ($runtimeIsMacOS) { 'macOS' } else { $runtimePlatform })
    if (-not $ldapProtocolsAvailable) {
        $missingPrerequisites.Add('System.DirectoryServices.Protocols is not available for the current PowerShell runtime.') | Out-Null

        if ($runtimeIsWindows) {
            $remediationActions.Add('Install or repair a supported .NET runtime that includes System.DirectoryServices.Protocols, then restart PowerShell.') | Out-Null
        }
        elseif ($runtimeIsMacOS) {
            $remediationActions.Add('Install or repair PowerShell 7 and the required LDAP native libraries, then verify System.DirectoryServices.Protocols is present in the runtime.') | Out-Null
        }
        else {
            $remediationActions.Add('Install or repair PowerShell 7 and the required LDAP native libraries, then verify System.DirectoryServices.Protocols is present in the runtime.') | Out-Null
        }
    }

    if (-not $runtimeIsWindows) {
        $pswsmanAvailable = if ($PSBoundParameters.ContainsKey('PSWSManInstalled')) {
            [bool]$PSWSManInstalled
        }
        else {
            $null -ne (Get-Module -ListAvailable -Name 'PSWSMan' | Sort-Object Version -Descending | Select-Object -First 1)
        }

        if (-not $pswsmanAvailable) {
            $missingPrerequisites.Add('PSWSMan is not installed, so WSMan/PSRP transport is unavailable on this non-Windows host.') | Out-Null
            $remediationActions.Add('Install-PSResource PSWSMan -Scope CurrentUser') | Out-Null
            $remediationActions.Add('Install-Module PSWSMan -Scope CurrentUser') | Out-Null
        }

        $smbClientPresent = if ($PSBoundParameters.ContainsKey('SmbClientAvailable')) {
            [bool]$SmbClientAvailable
        }
        else {
            $null -ne (Get-Command -Name 'smbclient' -ErrorAction SilentlyContinue)
        }

        if (-not $smbClientPresent) {
            $missingPrerequisites.Add('The smbclient binary is not available in PATH for SMB and SYSVOL access on this non-Windows host.') | Out-Null

            if ($runtimeIsMacOS) {
                $remediationActions.Add('brew install samba') | Out-Null
            }
            else {
                $remediationActions.Add('Install your platform smbclient package (for example: sudo apt-get install smbclient or sudo dnf install samba-client).') | Out-Null
            }
        }
    }

    if ($runtimeProfileName -eq 'Unknown') {
        $missingPrerequisites.Add('The current PowerShell platform is not mapped to a supported Active Directory runtime profile.') | Out-Null
        $remediationActions.Add('Use Windows PowerShell 5.1, Windows PowerShell 7, Linux PowerShell 7, or macOS PowerShell 7 for cross-platform Active Directory LDAP connectivity.') | Out-Null
    }

    $authModes = if ($null -ne $runtimeProfile) { [string[]]@($runtimeProfile.SupportedAuthModes) } else { [string[]]@() }
    $tlsModes = if ($null -ne $runtimeProfile) { [string[]]@($runtimeProfile.TlsModes) } else { [string[]]@('Ldaps', 'StartTls') }

    return [PSCustomObject]@{
        IsReady              = ($missingPrerequisites.Count -eq 0)
        MissingPrerequisites = [string[]]@($missingPrerequisites)
        RemediationActions   = [string[]]@($remediationActions | Select-Object -Unique)
        AuthModes            = $authModes
        TlsModes             = $tlsModes
        PlatformProfile      = $runtimeProfileName
        PSEdition            = $runtimePSEdition
        Platform             = $runtimePlatform
        PowerShellVersion    = $runtimePSVersion.ToString()
    }
}
