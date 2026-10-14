function Get-MtLdapCertificateDetail {
    <#
    .SYNOPSIS
    Extracts and logs details from an LDAP server certificate.

    .DESCRIPTION
    Converts the supplied X509Certificate to an X509Certificate2 and writes
    Subject, Issuer, Thumbprint, validity period, and SerialNumber to the
    verbose stream. The details are also returned as a hashtable so callers
    can include them in error messages or diagnostics.

    .PARAMETER Certificate
    The X509Certificate presented by the LDAP server during TLS negotiation.

    .EXAMPLE
    Get-MtLdapCertificateDetail -Certificate $certificate

    Writes verbose certificate details and returns a detail hashtable.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate]$Certificate
    )

    $cert2 = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $Certificate

    $details = [ordered]@{
        Subject      = $cert2.Subject
        Issuer       = $cert2.Issuer
        Thumbprint   = $cert2.Thumbprint
        NotBefore    = $cert2.NotBefore
        NotAfter     = $cert2.NotAfter
        SerialNumber = $cert2.SerialNumber
    }

    Write-Verbose "LDAP Server Certificate detected: Subject='$($details.Subject)', Issuer='$($details.Issuer)', Thumbprint='$($details.Thumbprint)', Valid='$($details.NotBefore)' to '$($details.NotAfter)'."

    return $details
}
