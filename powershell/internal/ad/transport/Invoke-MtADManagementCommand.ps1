function Invoke-MtADManagementCommand {
    <#
    .SYNOPSIS
    Runs an allow-listed Active Directory management operation over WSMan/PSRP.

    .DESCRIPTION
    Creates a short-lived credentialed PSSession to the server resolved by the
    current Maester Active Directory connection. HTTPS with normal certificate
    validation is attempted first. An HTTP Negotiate fallback, which retains
    WSMan message encryption, is available only when explicitly enabled.

    On non-Windows hosts, the optional PSWSMan module must be installed. The
    function invokes only fixed DNS inventory and SMB configuration
    scriptblocks, applies an operation timeout, honors cancellation at operation
    boundaries, and always removes a created PSSession.

    .PARAMETER Operation
    The fixed management operation to run. Supported values are DnsInventory
    and SmbConfiguration.

    .PARAMETER ComputerName
    The server targeted by the management session. Defaults to the server
    resolved by the current Maester Active Directory connection.

    .PARAMETER TimeoutSeconds
    The WSMan operation timeout in seconds. The value must be between 1 and
    3600 seconds.

    .PARAMETER CancellationToken
    An optional cancellation token checked before connection, before remote
    invocation, and after the remote operation returns.

    .PARAMETER AllowNegotiateFallback
    Allows fallback from validated HTTPS to HTTP with Negotiate authentication
    and WSMan message encryption. This function never changes TrustedHosts.

    .EXAMPLE
    Invoke-MtADManagementCommand -Operation SmbConfiguration

    Retrieves the allow-listed SMB server configuration properties from the
    resolved domain controller over validated HTTPS.

    .EXAMPLE
    Invoke-MtADManagementCommand -Operation DnsInventory -TimeoutSeconds 90 -AllowNegotiateFallback

    Retrieves MicrosoftDNS WMI inventory and explicitly permits a Negotiate
    fallback if the validated HTTPS connection cannot be established.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'CancellationToken', Justification = 'The token is consumed by the nested cancellation guard.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DnsInventory', 'SmbConfiguration')]
        [string] $Operation,

        [string] $ComputerName = [string]$__MtSession.ADConnection.ResolvedServer,

        [ValidateRange(1, 3600)]
        [int] $TimeoutSeconds = 60,

        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None,

        [switch] $AllowNegotiateFallback
    )

    function Get-MtManagementError {
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param(
            [Parameter(Mandatory)]
            [string] $Category,

            [Parameter(Mandatory)]
            [string] $Message
        )

        return [PSCustomObject][ordered]@{
            Operation       = $Operation
            Target          = $target
            ErrorCategory   = $Category
            RedactedMessage = $Message
        }
    }

    function Get-MtManagementErrorCategory {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory)]
            [System.Management.Automation.ErrorRecord] $ErrorRecord
        )

        $exception = $ErrorRecord.Exception
        $innerException = $exception.InnerException

        if ($exception -is [System.OperationCanceledException] -or $innerException -is [System.OperationCanceledException]) {
            return 'Cancelled'
        }

        if ($exception -is [System.TimeoutException] -or $innerException -is [System.TimeoutException] -or
            $exception.Message -match '(?i)timed?\s*out|operation\s+timeout\s+(?:expired|exceeded)') {
            return 'Timeout'
        }

        if ($ErrorRecord.Exception.Message -match '(?i)certificate|ssl|tls|certificate authority|CN check|CA check') {
            return 'CertificateValidation'
        }

        if ($ErrorRecord.Exception.Message -match '(?i)access is denied|authentication|credential|logon failure|unauthorized|0x8009030e') {
            return 'Authentication'
        }

        if ($exception -is [System.IO.InvalidDataException] -or $innerException -is [System.IO.InvalidDataException]) {
            return 'ResponseValidation'
        }

        return 'Connection'
    }

    function Get-MtManagementRedactedMessage {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory)]
            [string] $Category
        )

        switch ($Category) {
            'Authentication' { return 'Authentication failed while establishing the management session.' }
            'CertificateValidation' { return 'TLS certificate validation failed while establishing the management session.' }
            'Timeout' { return 'The management operation exceeded its configured timeout.' }
            'Cancelled' { return 'The management operation was cancelled.' }
            'ResponseValidation' { return 'The management endpoint returned an invalid response.' }
            default { return 'The management session could not complete the requested operation.' }
        }
    }

    function Assert-MtManagementNotCancelled {
        [CmdletBinding()]
        param()

        if ($CancellationToken.IsCancellationRequested) {
            throw [System.OperationCanceledException]::new('The management operation was cancelled.')
        }
    }

    $target = $ComputerName
    $credential = $__MtSession.ADCredential

    if ([string]::IsNullOrWhiteSpace($target)) {
        return Get-MtManagementError -Category 'Capability' -Message 'No resolved Active Directory server is available for management operations.'
    }

    if ($null -eq $credential) {
        return Get-MtManagementError -Category 'Capability' -Message 'An Active Directory credential is required for management operations.'
    }

    $platformProfile = (Test-MtAdProtocolPrerequisites).PlatformProfile
    $isWindowsRuntime = $platformProfile -like 'Windows*'

    if (-not $isWindowsRuntime) {
        $pswsmanModule = Get-Module -ListAvailable -Name 'PSWSMan' |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if ($null -eq $pswsmanModule) {
            return Get-MtManagementError -Category 'Capability' -Message 'PSWSMan is required for management operations on non-Windows hosts.'
        }

        try {
            Import-Module PSWSMan -ErrorAction Stop
            Enable-PSWSMan -Force -ErrorAction Stop | Out-Null
        }
        catch {
            return Get-MtManagementError -Category 'Capability' -Message 'PSWSMan could not be enabled for management operations on this host.'
        }
    }

    $smbConfigurationScript = {
        param(
            [string] $DomainControllerName
        )

        $configuration = Get-SmbServerConfiguration -ErrorAction Stop
        [PSCustomObject]@{
            DCName                    = $DomainControllerName
            EnableSMB1Protocol        = [bool]$configuration.EnableSMB1Protocol
            EnableSMB2Protocol        = [bool]$configuration.EnableSMB2Protocol
            EnableSMB3_1_1Protocol    = [bool]$configuration.EnableSMB3_1_1Protocol
            EnableSecuritySignature   = [bool]$configuration.EnableSecuritySignature
            RequireSecuritySignature  = [bool]$configuration.RequireSecuritySignature
        }
    }

    $dnsInventoryScript = {
        $zones = @(Get-CimInstance -Namespace 'root\MicrosoftDNS' -ClassName 'MicrosoftDNS_Zone' -ErrorAction Stop)
        $records = @(Get-CimInstance -Namespace 'root\MicrosoftDNS' -ClassName 'MicrosoftDNS_ResourceRecord' -ErrorAction Stop)
        $rootHints = @(Get-CimInstance -Namespace 'root\MicrosoftDNS' -ClassName 'MicrosoftDNS_RootHints' -ErrorAction Stop)

        [PSCustomObject]@{
            Zones     = $zones
            Records   = $records
            RootHints = $rootHints
        }
    }

    $connectionAttempts = [System.Collections.Generic.List[object]]::new()
    $connectionAttempts.Add([PSCustomObject][ordered]@{
            Name                  = 'HTTPS'
            UseSSL                = $true
            SkipCertificateChecks = $false
        })

    if ($AllowNegotiateFallback.IsPresent) {
        $connectionAttempts.Add([PSCustomObject][ordered]@{
                Name                  = 'HTTP'
                UseSSL                = $false
                SkipCertificateChecks = $true
            })
    }

    $lastError = $null
    foreach ($connectionAttempt in $connectionAttempts) {
        $session = $null
        try {
            Assert-MtManagementNotCancelled
            Write-Verbose "Starting $Operation management operation against '$target' using $($connectionAttempt.Name)."

            $sessionOptionParameters = [ordered]@{
                OperationTimeout = $TimeoutSeconds * 1000
            }
            if ($connectionAttempt.SkipCertificateChecks) {
                $sessionOptionParameters['SkipCACheck'] = $true
                $sessionOptionParameters['SkipCNCheck'] = $true
            }
            $sessionOption = if ($isWindowsRuntime) {
                New-PSSessionOption @sessionOptionParameters
            }
            else {
                New-PSWSManSessionOption @sessionOptionParameters
            }

            $sessionParameters = [ordered]@{
                ComputerName  = $target
                Authentication = 'Negotiate'
                Credential    = $credential
                SessionOption = $sessionOption
                ErrorAction   = 'Stop'
            }
            if ($connectionAttempt.UseSSL) {
                $sessionParameters['UseSSL'] = $true
            }

            $session = New-PSSession @sessionParameters
            Assert-MtManagementNotCancelled

            $rawResult = switch ($Operation) {
                'SmbConfiguration' {
                    Invoke-Command -Session $session -ScriptBlock $smbConfigurationScript -ArgumentList ([string]$target) -ErrorAction Stop
                }
                'DnsInventory' {
                    Invoke-Command -Session $session -ScriptBlock $dnsInventoryScript -ErrorAction Stop
                }
            }

            Assert-MtManagementNotCancelled

            if ($Operation -eq 'SmbConfiguration') {
                $configuration = @($rawResult)
                if ($configuration.Count -ne 1) {
                    throw [System.IO.InvalidDataException]::new('Management response validation failed.')
                }

                foreach ($propertyName in @('EnableSMB1Protocol', 'EnableSMB2Protocol', 'EnableSMB3_1_1Protocol', 'EnableSecuritySignature', 'RequireSecuritySignature')) {
                    if ($configuration[0].PSObject.Properties.Name -notcontains $propertyName -or $configuration[0].$propertyName -isnot [bool]) {
                        throw [System.IO.InvalidDataException]::new('Management response validation failed.')
                    }
                }

                return [PSCustomObject][ordered]@{
                    DCName                   = [string]$target
                    EnableSMB1Protocol       = [bool]$configuration[0].EnableSMB1Protocol
                    EnableSMB2Protocol       = [bool]$configuration[0].EnableSMB2Protocol
                    EnableSMB3_1_1Protocol   = [bool]$configuration[0].EnableSMB3_1_1Protocol
                    EnableSecuritySignature  = [bool]$configuration[0].EnableSecuritySignature
                    RequireSecuritySignature = [bool]$configuration[0].RequireSecuritySignature
                }
            }

            $inventory = @($rawResult)
            if ($inventory.Count -ne 1 -or
                $inventory[0].PSObject.Properties.Name -notcontains 'Zones' -or
                $inventory[0].PSObject.Properties.Name -notcontains 'Records' -or
                $inventory[0].PSObject.Properties.Name -notcontains 'RootHints') {
                throw [System.IO.InvalidDataException]::new('Management response validation failed.')
            }

            return [PSCustomObject][ordered]@{
                Zones     = @($inventory[0].Zones)
                Records   = @($inventory[0].Records)
                RootHints = @($inventory[0].RootHints)
            }
        }
        catch {
            $lastError = $_
            Write-Verbose "The $($connectionAttempt.Name) management attempt failed with a redacted error."
        }
        finally {
            if ($null -ne $session) {
                try {
                    Remove-PSSession -Session $session -ErrorAction Stop
                }
                catch {
                    Write-Verbose 'Failed to remove the management PSSession.'
                }
            }
        }
    }

    $errorCategory = Get-MtManagementErrorCategory -ErrorRecord $lastError
    $redactedMessage = Get-MtManagementRedactedMessage -Category $errorCategory
    return Get-MtManagementError -Category $errorCategory -Message $redactedMessage
}
