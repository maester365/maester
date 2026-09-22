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

        [switch] $SkipCertificateCheck
    )

    $effectivePort = if ($UseStartTls.IsPresent -and -not $PSBoundParameters.ContainsKey('Port')) {
        389
    }
    else {
        $Port
    }

    if ($AuthType -eq 'Basic' -and -not $UseStartTls.IsPresent -and $effectivePort -ne 636) {
        throw 'Basic authentication requires LDAPS on port 636 or StartTLS.'
    }

    $identifier = $null
    $connection = $null
    $networkCredential = $null

    try {
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

            if ($SkipCertificateCheck.IsPresent) {
                # Dangerous: this bypass is allowed only for tests and fixtures.
                $connection.SessionOptions.VerifyServerCertificate = {
                    param($ldapConnection, $certificate)

                    [void]$ldapConnection
                    [void]$certificate
                    return $true
                }
            }
        }

        if ($PSBoundParameters.ContainsKey('Credential')) {
            $networkCredential = $Credential.GetNetworkCredential()
            $connection.Credential = $networkCredential
        }

        if ($UseStartTls.IsPresent) {
            $startTlsControls = New-Object -TypeName System.DirectoryServices.Protocols.DirectoryControlCollection
            $connection.SessionOptions.StartTransportLayerSecurity($startTlsControls)
        }

        $connection.Bind()
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

        throw "Failed to establish LDAP connection to '$Server' on port $effectivePort. $($_.Exception.Message)"
    }
    finally {
        $networkCredential = $null
    }
}
