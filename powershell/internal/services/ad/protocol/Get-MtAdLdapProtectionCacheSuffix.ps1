function Get-MtAdLdapProtectionCacheSuffix {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$ConnectionState
    )

    if ($ConnectionState.TlsMode -ne 'None') {
        return ''
    }

    return ":ldap-none:$($ConnectionState.AuthenticationMode):unsigned=$([bool]$ConnectionState.ForceUnsigned):plaintext-password=$([bool]$ConnectionState.AllowPlaintextPassword)"
}
