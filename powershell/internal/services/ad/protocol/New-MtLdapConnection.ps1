function New-MtLdapConnection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal connection factory that only creates an in-memory LDAP client object.')]
    [CmdletBinding()]
    [OutputType([System.DirectoryServices.Protocols.LdapConnection])]
    param(
        [Parameter(Mandatory)]
        [string] $Server,

        [int] $Port = 636,

        [switch] $UseStartTls,

        [System.Management.Automation.PSCredential] $Credential,

        [ValidateSet('Negotiate', 'Kerberos', 'Ntlm', 'Basic')]
        [string] $AuthType = 'Negotiate',

        [timespan] $Timeout = [timespan]::FromSeconds(30),

        [switch] $SkipCertificateCheck,

        [switch] $ForceUnencrypted,

        [switch] $ForceUnsigned,

        [switch] $AllowPlaintextPassword
    )

    $effectivePort = if ($UseStartTls.IsPresent -and -not $PSBoundParameters.ContainsKey('Port')) {
        389
    }
    else {
        $Port
    }

    $usesTls = $UseStartTls.IsPresent -or $effectivePort -eq 636
    if ($AuthType -eq 'Basic' -and -not $usesTls -and -not ($ForceUnencrypted.IsPresent -and $AllowPlaintextPassword.IsPresent)) {
        throw 'Basic authentication requires LDAPS on port 636 or StartTLS.'
    }
    if (-not $usesTls -and -not $ForceUnencrypted.IsPresent) {
        throw 'LDAP without TLS requires -ForceUnencrypted.'
    }
    if ($ForceUnsigned.IsPresent -and ($usesTls -or -not $ForceUnencrypted.IsPresent -or $AuthType -eq 'Basic')) {
        throw '-ForceUnsigned requires LDAP without TLS, -ForceUnencrypted, and Negotiate, Kerberos, or Ntlm authentication.'
    }
    if ($AllowPlaintextPassword.IsPresent -and ($usesTls -or -not $ForceUnencrypted.IsPresent -or $AuthType -ne 'Basic')) {
        throw '-AllowPlaintextPassword requires Basic authentication without TLS and -ForceUnencrypted.'
    }
    if ($AllowPlaintextPassword.IsPresent -and $null -eq $Credential) {
        throw '-AllowPlaintextPassword requires an explicit credential.'
    }
    if (-not $usesTls) {
        Write-MtLdapProtectionWarning -Server $Server -Port $effectivePort -AuthType $AuthType -ForceUnsigned:$ForceUnsigned
    }

    $identifier = $null
    $connection = $null
    $networkCredential = $null

    try {
        Write-Verbose "Creating LDAP connection to '$Server' on port $effectivePort with AuthType '$AuthType', UseStartTls: $($UseStartTls.IsPresent), SkipCertificateCheck: $($SkipCertificateCheck.IsPresent)"
        $identifier = New-Object -TypeName System.DirectoryServices.Protocols.LdapDirectoryIdentifier -ArgumentList @(
            $Server,
            $effectivePort,
            $false,
            $false
        )

        $connection = New-Object -TypeName System.DirectoryServices.Protocols.LdapConnection -ArgumentList $identifier
        $connection.AuthType = [System.DirectoryServices.Protocols.AuthType]::$AuthType
        $connection.Timeout = $Timeout

        if ($null -ne $connection.SessionOptions) {
            $connection.SessionOptions.ProtocolVersion = 3
            $connection.SessionOptions.ReferralChasing = [System.DirectoryServices.Protocols.ReferralChasingOptions]::None
            $connection.SessionOptions.SecureSocketLayer = ($effectivePort -eq 636 -and -not $UseStartTls.IsPresent)

            # When SkipCertificateCheck is present, install a callback that logs
            # certificate details and bypasses validation. When it is not present,
            # do not install a callback at all — the platform's TLS stack
            # (Schannel on Windows, OpenSSL on Linux) already performs chain
            # validation, hostname verification, expiry checking, and revocation
            # checking automatically.
            if ($SkipCertificateCheck.IsPresent) {
                try {
                    $callback = {
                        param($ldapConnection, $certificate)

                        [void]$ldapConnection
                        $script:__MtLastLdapCertificateDetail = Get-MtLdapCertificateDetail -Certificate $certificate
                        return $true
                    }.GetNewClosure()

                    # Bind the callback to the Maester module so internal functions like
                    # Get-MtLdapCertificateDetail are resolvable when .NET invokes it.
                    $maesterModule = Get-Module Maester
                    if ($null -ne $maesterModule) {
                        $callback = $maesterModule.NewBoundScriptBlock($callback)
                    }

                    $connection.SessionOptions.VerifyServerCertificate = $callback
                }
                catch {
                    Write-Verbose "Unable to set VerifyServerCertificate callback: $_."
                }
            }
        }

        # Explicit opt-outs must be honored, not silently left to provider defaults.
        # Basic/simple bind has no SASL layer; do not write SASL options on it or TLS.
        if (-not $usesTls -and $AuthType -ne 'Basic') {
            try {
                $connection.SessionOptions.Sealing = $false
                if ($connection.SessionOptions.Sealing) {
                    throw 'The provider did not disable SASL sealing.'
                }
                if ($ForceUnsigned.IsPresent) {
                    $connection.SessionOptions.Signing = $false
                    if ($connection.SessionOptions.Signing) {
                        throw 'The provider did not disable SASL signing.'
                    }
                }
            } catch {
                throw "The LDAP platform/provider cannot honor the requested SASL protection opt-outs. No bind was attempted. Use TLS or a supported client platform. $($_.Exception.Message)"
            }
        }

        if ($PSBoundParameters.ContainsKey('Credential')) {
            $networkCredential = $Credential.GetNetworkCredential()

            # When using Basic authentication, .NET System.DirectoryServices.Protocols
            # does not accept DNS domain format (e.g. domain.com\user) for the credential
            # domain. It requires either NetBIOS (DOMAIN\user) or UPN (user@domain.com).
            # If the domain contains a dot, convert to UPN format automatically.
            if ($AuthType -eq 'Basic' -and
                -not [string]::IsNullOrWhiteSpace($networkCredential.Domain) -and
                $networkCredential.Domain.Contains('.')) {
                $upnUserName = "$($networkCredential.UserName)@$($networkCredential.Domain)"
                $networkCredential = New-Object -TypeName System.Net.NetworkCredential -ArgumentList @(
                    $upnUserName,
                    $networkCredential.SecurePassword
                )
            }

            $connection.Credential = $networkCredential
        }

        if ($UseStartTls.IsPresent) {
            Write-Verbose "Negotiating StartTLS with server '$Server' on port $effectivePort"
            $startTlsControls = New-Object -TypeName System.DirectoryServices.Protocols.DirectoryControlCollection
            $connection.SessionOptions.StartTransportLayerSecurity($startTlsControls)
            Write-Verbose "StartTLS negotiation completed successfully"
        }

        Write-Verbose "Attempting LDAP bind to '$Server' on port $effectivePort with AuthType '$AuthType'"
        $connection.Bind()
        if (-not $usesTls -and $AuthType -ne 'Basic') {
            try {
                if ($connection.SessionOptions.Sealing) {
                    throw 'SASL sealing was re-enabled by the client platform or policy.'
                }
                if ($ForceUnsigned.IsPresent -and $connection.SessionOptions.Signing) {
                    throw 'SASL signing was re-enabled by the client platform or policy.'
                }
            } catch {
                throw "The LDAP platform/provider did not honor the requested protection opt-outs. The bind completed, but Maester did not issue a directory query after the bind. Maester does not change host or DC policy. $($_.Exception.Message)"
            }
        }
        Write-Verbose "LDAP bind to '$Server' on port $effectivePort succeeded"
        return $connection
    }
    catch {
        if ($null -ne $connection) {
            try {
                $connection.Dispose()
            }
            catch {
                Write-Verbose 'Failed to dispose the LDAP connection after a connection error.'
            }
        }

        Write-Verbose "LDAP connection to '$Server' on port $effectivePort failed: $($_.Exception.Message)"
        throw "Failed to establish LDAP connection to '$Server' on port $effectivePort. $($_.Exception.Message)"
    }
    finally {
        $networkCredential = $null
    }
}
