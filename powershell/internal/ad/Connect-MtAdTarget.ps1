function Connect-MtAdTarget {
    [CmdletBinding()]
    param(
        [object]$ActiveDirectoryForest,

        [object]$ActiveDirectoryDomain,

        [object]$ActiveDirectoryServer,

        [System.Management.Automation.PSCredential]$ActiveDirectoryCredential,

        [ValidateSet('Negotiate', 'Kerberos', 'Ntlm', 'Basic')]
        [string]$AuthMode = 'Negotiate',

        [ValidateSet('Auto', 'Ldaps', 'StartTls')]
        [string]$TlsMode = 'Auto',

        [switch]$PassThru
    )

    function Test-MtAdSelectorIsArray {
        param(
            $Value
        )

        return $null -ne $Value -and $Value -is [System.Array]
    }

    function Get-MtAdSanitizedErrorMessage {
        param(
            [System.Exception]$Exception
        )

        if ($null -eq $Exception -or [string]::IsNullOrWhiteSpace($Exception.Message)) {
            return 'Failed to connect to Active Directory.'
        }

        return ($Exception.Message -replace '(?i)(ldap(?:s)?://)?[^/\s:@]+:[^@\s/]+@', '$1<redacted>@')
    }

    function ConvertFrom-MtNamingContextToDnsName {
        param(
            [string]$NamingContext
        )

        if ([string]::IsNullOrWhiteSpace($NamingContext)) {
            return $null
        }

        $components = @([regex]::Matches($NamingContext, '(?i)(?<=^|,)DC=([^,]+)') | ForEach-Object { $_.Groups[1].Value })
        if ($components.Count -eq 0) {
            return $null
        }

        return (($components | ForEach-Object { $_.Trim() }) -join '.').ToLowerInvariant()
    }

    function ConvertTo-MtNormalizedDnsName {
        param(
            [string]$Value
        )

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $null
        }

        return $Value.Trim().Trim('.').ToLowerInvariant()
    }

    function Test-MtDomainWithinForest {
        param(
            [string]$Domain,
            [string]$Forest
        )

        $normalizedDomain = ConvertTo-MtNormalizedDnsName -Value $Domain
        $normalizedForest = ConvertTo-MtNormalizedDnsName -Value $Forest

        if ([string]::IsNullOrWhiteSpace($normalizedDomain) -or [string]::IsNullOrWhiteSpace($normalizedForest)) {
            return $false
        }

        return $normalizedDomain -eq $normalizedForest -or $normalizedDomain.EndsWith(".$normalizedForest")
    }

    function Test-MtServerMatchesHostName {
        param(
            [string]$RequestedServer,
            [string]$ResolvedServer
        )

        $normalizedRequested = ConvertTo-MtNormalizedDnsName -Value $RequestedServer
        $normalizedResolved = ConvertTo-MtNormalizedDnsName -Value $ResolvedServer

        if ([string]::IsNullOrWhiteSpace($normalizedRequested) -or [string]::IsNullOrWhiteSpace($normalizedResolved)) {
            return $false
        }

        return $normalizedRequested -eq $normalizedResolved -or $normalizedResolved.StartsWith("$normalizedRequested.")
    }

    function Close-MtAdLdapConnection {
        param(
            $Connection
        )

        if ($null -eq $Connection) {
            return
        }

        try {
            if ($Connection -is [System.IDisposable]) {
                $Connection.Dispose()
                return
            }

            $disposeMethod = $Connection.PSObject.Methods['Dispose']
            if ($null -ne $disposeMethod) {
                [void]$disposeMethod.Invoke()
            }
        }
        catch {
            Write-Verbose 'Failed to dispose the LDAP connection after Active Directory target resolution.'
        }
    }

    function Get-MtAdSessionState {
        param(
            [bool]$Connected,
            [string]$ErrorMessage = $null,
            [string]$ResolvedForest = $null,
            [string]$ResolvedDomain = $null,
            [string]$ResolvedServer = $null,
            [string]$DefaultNamingContext = $null,
            [string]$ConfigurationNamingContext = $null,
            [string]$SchemaNamingContext = $null,
            [string]$SelectedTlsMode = $null,
            [string]$AuthenticationMode = $null
        )

        return [ordered]@{
            Connected                  = $Connected
            ProtocolValidated          = $Connected
            ProtocolPath               = 'Connect-MtAdTarget/New-MtLdapConnection/Get-MtLdapRootDse'
            Error                      = $ErrorMessage
            RequestedForest            = $ActiveDirectoryForest
            RequestedDomain            = $ActiveDirectoryDomain
            RequestedServer            = $ActiveDirectoryServer
            RequestedAuthMode          = $AuthMode
            RequestedTlsMode           = $TlsMode
            ResolvedForest             = $ResolvedForest
            ResolvedDomain             = $ResolvedDomain
            ResolvedServer             = $ResolvedServer
            DefaultNamingContext       = $DefaultNamingContext
            ConfigurationNamingContext = $ConfigurationNamingContext
            SchemaNamingContext        = $SchemaNamingContext
            TlsMode                    = $SelectedTlsMode
            AuthenticationMode         = $AuthenticationMode
            Capabilities               = [ordered]@{
                SupportsPaging             = $true
                SupportsRangeRetrieval     = $true
                SupportsSecurityDescriptor = $true
                SupportsDns                = $true
                SupportsSysvol             = $true
            }
        }
    }

    function Get-MtDiscoveredDomainController {
        param(
            [Parameter(Mandatory)]
            [string]$DnsName,

            [Parameter(Mandatory)]
            [string]$DiscoveryScope
        )

        if ($null -eq (Get-Command -Name 'Resolve-DnsName' -ErrorAction SilentlyContinue)) {
            throw "Unable to discover a domain controller for '$DnsName'. Resolve-DnsName is not available on this platform."
        }

        $records = @(Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DnsName" -Type SRV -ErrorAction Stop)
        if ($records.Count -eq 0) {
            throw "Unable to discover a domain controller for the requested $DiscoveryScope '$DnsName'."
        }

        $record = $records |
            Sort-Object -Property Priority, Weight |
            Select-Object -First 1

        $targetServer = @(
            $record.NameTarget
            $record.DomainName
            $record.NameHost
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1

        if ([string]::IsNullOrWhiteSpace($targetServer)) {
            throw "Unable to discover a domain controller for the requested $DiscoveryScope '$DnsName'."
        }

        return $targetServer.TrimEnd('.').ToLowerInvariant()
    }

    function Get-MtAmbientDomainController {
        $ambientLogonServer = ConvertTo-MtNormalizedDnsName -Value ($env:LOGONSERVER -replace '^[\\/]+', '')
        if (-not [string]::IsNullOrWhiteSpace($ambientLogonServer)) {
            return $ambientLogonServer
        }

        $ambientDomain = ConvertTo-MtNormalizedDnsName -Value $env:USERDNSDOMAIN
        if (-not [string]::IsNullOrWhiteSpace($ambientDomain)) {
            return Get-MtDiscoveredDomainController -DnsName $ambientDomain -DiscoveryScope 'domain'
        }

        # Fallback for non-interactive sessions (e.g., GSSAPI SSH) where environment variables
        # are not populated but a valid domain identity exists via Kerberos.
        try {
            $currentDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            if ($null -ne $currentDomain -and $null -ne $currentDomain.PdcRoleOwner) {
                $fallbackDc = ConvertTo-MtNormalizedDnsName -Value $currentDomain.PdcRoleOwner.Name
                if (-not [string]::IsNullOrWhiteSpace($fallbackDc)) {
                    return $fallbackDc
                }
            }
        }
        catch {
            Write-Verbose 'GetCurrentDomain fallback failed; will throw original error.'
        }

        throw 'Unable to discover an ambient Active Directory domain controller for the current Windows session.'
    }

    function Get-MtAdTargetState {
        param(
            [Parameter(Mandatory)]
            $Connection,

            [Parameter(Mandatory)]
            [pscustomobject]$RootDse,

            [Parameter(Mandatory)]
            [string]$ConnectedServer,

            [Parameter(Mandatory)]
            [string]$TlsMode,

            [Parameter(Mandatory)]
            [string]$AuthenticationMode
        )

        $resolvedDomain = ConvertFrom-MtNamingContextToDnsName -NamingContext $RootDse.DefaultNamingContext
        $resolvedForest = $null

        if (-not [string]::IsNullOrWhiteSpace($RootDse.ConfigurationNamingContext)) {
            $crossRefs = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $RootDse.ConfigurationNamingContext -Scope Subtree -Filter '(objectClass=crossRef)' -Attributes @('dnsRoot', 'nCName', 'trustParent') -PageSize 0)
            $domainCrossRefs = @($crossRefs | Where-Object {
                    -not [string]::IsNullOrWhiteSpace([string]$_.dnsRoot) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.nCName)
                })

            $currentDomainCrossRef = $domainCrossRefs | Where-Object {
                [string]$_.nCName -eq $RootDse.DefaultNamingContext
            } | Select-Object -First 1

            if ($null -ne $currentDomainCrossRef -and [string]::IsNullOrWhiteSpace($resolvedDomain)) {
                $resolvedDomain = ConvertTo-MtNormalizedDnsName -Value ([string]$currentDomainCrossRef.dnsRoot)
            }

            $rootDomainCrossRef = $domainCrossRefs | Where-Object {
                [string]$_.nCName -eq $RootDse.RootDomainNamingContext
            } | Select-Object -First 1

            if ($null -ne $rootDomainCrossRef) {
                $resolvedForest = ConvertTo-MtNormalizedDnsName -Value ([string]$rootDomainCrossRef.dnsRoot)
            }
        }

        if ([string]::IsNullOrWhiteSpace($resolvedForest)) {
            $resolvedForest = $resolvedDomain
        }

        return [PSCustomObject]@{
            ResolvedForest             = $resolvedForest
            ResolvedDomain             = $resolvedDomain
            ResolvedServer             = ConvertTo-MtNormalizedDnsName -Value $(if ([string]::IsNullOrWhiteSpace($RootDse.DnsHostName)) { $ConnectedServer } else { [string]$RootDse.DnsHostName })
            DefaultNamingContext       = [string]$RootDse.DefaultNamingContext
            ConfigurationNamingContext = [string]$RootDse.ConfigurationNamingContext
            SchemaNamingContext        = [string]$RootDse.SchemaNamingContext
            TlsMode                    = $TlsMode
            AuthenticationMode         = $AuthenticationMode
        }
    }

    function Connect-MtAdResolvedTarget {
        param(
            [Parameter(Mandatory)]
            [string]$Server,

            [System.Management.Automation.PSCredential]$Credential,

            [Parameter(Mandatory)]
            [string]$AuthenticationMode,

            [Parameter(Mandatory)]
            [string]$RequestedTlsMode
        )

        $lastException = $null

        $tlsAttempts = switch ($RequestedTlsMode) {
            'Ldaps' { @(@{ Name = 'Ldaps'; Port = 636; UseStartTls = $false }) }
            'StartTls' { @(@{ Name = 'StartTls'; Port = 389; UseStartTls = $true }) }
            default {
                @(
                    @{ Name = 'Ldaps'; Port = 636; UseStartTls = $false }
                    @{ Name = 'StartTls'; Port = 389; UseStartTls = $true }
                )
            }
        }

        foreach ($tlsAttempt in $tlsAttempts) {
            $connection = $null
            try {
                $connectionParameters = @{
                    Server   = $Server
                    Port     = $tlsAttempt.Port
                    AuthType = $AuthenticationMode
                }

                if ($tlsAttempt.UseStartTls) {
                    $connectionParameters['UseStartTls'] = $true
                }

                if ($null -ne $Credential) {
                    $connectionParameters['Credential'] = $Credential
                }

                $connection = New-MtLdapConnection @connectionParameters
                $rootDse = Get-MtLdapRootDse -Connection $connection
                $targetMetadata = Get-MtAdTargetState -Connection $connection -RootDse $rootDse -ConnectedServer $Server -TlsMode $tlsAttempt.Name -AuthenticationMode $AuthenticationMode

                return [PSCustomObject]@{
                    Connection = $connection
                    Metadata   = $targetMetadata
                }
            }
            catch {
                $lastException = $_.Exception
                Close-MtAdLdapConnection -Connection $connection
            }
        }

        throw $lastException
    }

    Write-Verbose 'Validating Active Directory connectivity'

    if (-not $PassThru.IsPresent) {
        $__MtSession.ADCredential = $null
    }
    $adConnectionState = Get-MtAdSessionState -Connected $false
    $resolvedConnection = $null

    try {
        foreach ($selectorValue in @($ActiveDirectoryForest, $ActiveDirectoryDomain, $ActiveDirectoryServer, $ActiveDirectoryCredential)) {
            if (Test-MtAdSelectorIsArray -Value $selectorValue) {
                throw 'Selectors are scalar-only; arrays are invalid.'
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryForest) -and -not [string]::IsNullOrWhiteSpace($ActiveDirectoryDomain) -and -not (Test-MtDomainWithinForest -Domain $ActiveDirectoryDomain -Forest $ActiveDirectoryForest)) {
            throw 'Explicit selector values must resolve to the same forest/domain/server.'
        }

        $adPrerequisites = Test-MtAdProtocolPrerequisites
        if ($adPrerequisites.PlatformProfile -eq 'Unknown' -or $adPrerequisites.AuthModes.Count -eq 0) {
            throw 'The current PowerShell platform does not support Active Directory LDAP target resolution.'
        }

        $isWindowsRuntime = $adPrerequisites.PlatformProfile -like 'Windows*'
        $hasExplicitSelector =
            -not [string]::IsNullOrWhiteSpace($ActiveDirectoryForest) -or
            -not [string]::IsNullOrWhiteSpace($ActiveDirectoryDomain) -or
            -not [string]::IsNullOrWhiteSpace($ActiveDirectoryServer)

        if (-not $isWindowsRuntime -and -not $hasExplicitSelector) {
            throw 'Non-Windows platforms require an explicit Active Directory endpoint. Use -ActiveDirectoryServer, -ActiveDirectoryDomain, or -ActiveDirectoryForest.'
        }

        if (-not $isWindowsRuntime -and $null -eq $ActiveDirectoryCredential) {
            throw 'Non-Windows platforms require -ActiveDirectoryCredential for Active Directory LDAP connections.'
        }

        if (-not $isWindowsRuntime -and -not [string]::IsNullOrWhiteSpace($ActiveDirectoryDomain) -and [string]::IsNullOrWhiteSpace($ActiveDirectoryServer)) {
            throw 'Non-Windows platforms require -ActiveDirectoryServer when targeting a domain. Supply -ActiveDirectoryServer together with -ActiveDirectoryDomain.'
        }

        $authenticationMode = $AuthMode
        if ($adPrerequisites.AuthModes -notcontains $authenticationMode) {
            throw "Authentication mode '$authenticationMode' is not supported on this platform profile."
        }

        if ($adPrerequisites.TlsModes -notcontains $TlsMode -and $TlsMode -ne 'Auto') {
            throw "TLS mode '$TlsMode' is not supported on this platform profile."
        }

        if ($authenticationMode -eq 'Basic' -and $null -eq $ActiveDirectoryCredential) {
            throw 'Basic authentication requires -ActiveDirectoryCredential.'
        }

        $targetServer = $null
        if (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryServer)) {
            $targetServer = ConvertTo-MtNormalizedDnsName -Value $ActiveDirectoryServer
        }
        elseif (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryDomain)) {
            $targetServer = Get-MtDiscoveredDomainController -DnsName (ConvertTo-MtNormalizedDnsName -Value $ActiveDirectoryDomain) -DiscoveryScope 'domain'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryForest)) {
            $targetServer = Get-MtDiscoveredDomainController -DnsName (ConvertTo-MtNormalizedDnsName -Value $ActiveDirectoryForest) -DiscoveryScope 'forest'
        }
        else {
            $targetServer = Get-MtAmbientDomainController
        }

        $resolvedConnection = Connect-MtAdResolvedTarget -Server $targetServer -Credential $ActiveDirectoryCredential -AuthenticationMode $authenticationMode -RequestedTlsMode $TlsMode
        $adConnectionState = Get-MtAdSessionState -Connected $true `
            -ResolvedForest $resolvedConnection.Metadata.ResolvedForest `
            -ResolvedDomain $resolvedConnection.Metadata.ResolvedDomain `
            -ResolvedServer $resolvedConnection.Metadata.ResolvedServer `
            -DefaultNamingContext $resolvedConnection.Metadata.DefaultNamingContext `
            -ConfigurationNamingContext $resolvedConnection.Metadata.ConfigurationNamingContext `
            -SchemaNamingContext $resolvedConnection.Metadata.SchemaNamingContext `
            -SelectedTlsMode $resolvedConnection.Metadata.TlsMode `
            -AuthenticationMode $resolvedConnection.Metadata.AuthenticationMode

        if (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryForest) -and (ConvertTo-MtNormalizedDnsName -Value $resolvedConnection.Metadata.ResolvedForest) -ne (ConvertTo-MtNormalizedDnsName -Value $ActiveDirectoryForest)) {
            throw 'Explicit selector values must resolve to the same forest/domain/server.'
        }

        if (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryDomain) -and (ConvertTo-MtNormalizedDnsName -Value $resolvedConnection.Metadata.ResolvedDomain) -ne (ConvertTo-MtNormalizedDnsName -Value $ActiveDirectoryDomain)) {
            throw 'Explicit selector values must resolve to the same forest/domain/server.'
        }

        if (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryServer) -and -not (Test-MtServerMatchesHostName -RequestedServer $ActiveDirectoryServer -ResolvedServer $resolvedConnection.Metadata.ResolvedServer)) {
            throw 'Explicit selector values must resolve to the same forest/domain/server.'
        }

        if (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryServer) -and -not [string]::IsNullOrWhiteSpace($ActiveDirectoryDomain) -and (ConvertTo-MtNormalizedDnsName -Value $resolvedConnection.Metadata.ResolvedDomain) -ne (ConvertTo-MtNormalizedDnsName -Value $ActiveDirectoryDomain)) {
            throw 'Explicit selector values must resolve to the same forest/domain/server.'
        }

        if (-not [string]::IsNullOrWhiteSpace($ActiveDirectoryServer) -and -not [string]::IsNullOrWhiteSpace($ActiveDirectoryForest) -and -not (Test-MtDomainWithinForest -Domain $resolvedConnection.Metadata.ResolvedDomain -Forest $ActiveDirectoryForest)) {
            throw 'Explicit selector values must resolve to the same forest/domain/server.'
        }

        if ($PassThru.IsPresent) {
            return [PSCustomObject]$adConnectionState
        }

        $__MtSession.ADCredential = $ActiveDirectoryCredential
        $__MtSession.ADConnection = $adConnectionState
        Write-Verbose "Connected to AD: $($resolvedConnection.Metadata.ResolvedServer)"
    }
    catch {
        $sanitizedError = Get-MtAdSanitizedErrorMessage -Exception $_.Exception
        if (-not $PassThru.IsPresent) {
            $__MtSession.ADCredential = $null
            $__MtSession.ADConnection = Get-MtAdSessionState -Connected $false -ErrorMessage $sanitizedError
        }
        throw "Failed to connect to Active Directory: $sanitizedError"
    }
    finally {
        if ($null -ne $resolvedConnection) {
            Close-MtAdLdapConnection -Connection $resolvedConnection.Connection
        }
    }
}
