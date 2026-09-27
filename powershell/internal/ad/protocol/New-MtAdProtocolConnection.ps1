function New-MtAdProtocolConnection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal connection factory that only creates an in-memory LDAP client object from cached session evidence.')]
    <#
    .SYNOPSIS
    Creates an LDAP connection from cached Active Directory protocol evidence.

    .DESCRIPTION
    Wraps New-MtLdapConnection by building connection parameters from the
    resolved protocol evidence stored in a Maester session. This eliminates
    the repeated boilerplate for port/TLS/credential selection across AD
    cmdlets and tests.

    .PARAMETER ProtocolEvidence
    A PSObject or hashtable containing at least ResolvedServer, AuthenticationMode
    and TlsMode (e.g. $adState.ProtocolEvidence or a Connect-MtAdTarget PassThru result).

    .EXAMPLE
    $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence

    .EXAMPLE
    $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $protocolConnectionState
    #>
    [CmdletBinding()]
    [OutputType([System.DirectoryServices.Protocols.LdapConnection])]
    param(
        [Parameter(Mandatory)]
        [object]$ProtocolEvidence
    )

    $ldapConnectionParameters = @{
        Server   = $ProtocolEvidence.ResolvedServer
        AuthType = $ProtocolEvidence.AuthenticationMode
    }

    if ($ProtocolEvidence.TlsMode -eq 'StartTls') {
        $ldapConnectionParameters['Port'] = 389
        $ldapConnectionParameters['UseStartTls'] = $true
    } else {
        $ldapConnectionParameters['Port'] = 636
    }

    if ($null -ne $__MtSession.ADCredential) {
        $ldapConnectionParameters['Credential'] = $__MtSession.ADCredential
    }

    return New-MtLdapConnection @ldapConnectionParameters
}
