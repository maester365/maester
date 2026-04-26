function Test-MtAdSupportedSaslMechanismDetails {
    <#
    .SYNOPSIS
    Retrieves detailed information about supported SASL mechanisms.

    .DESCRIPTION
    Simple Authentication and Security Layer (SASL) mechanisms define how
    clients authenticate to Active Directory. This test provides detailed
    information about each supported mechanism and its security implications.

    Key SASL Mechanisms:
    - GSSAPI: Generic Security Services API (Kerberos) - Most secure
    - GSS-SPNEGO: SPNEGO negotiation for Kerberos/NTLM
    - EXTERNAL: Authentication via external means (TLS client certs)
    - DIGEST-MD5: Digest authentication (less secure, often disabled)

    Security Best Practice:
    - Prefer Kerberos (GSSAPI) for authentication
    - Minimize use of less secure mechanisms
    - Disable DIGEST-MD5 if not required

    .EXAMPLE
    Test-MtAdSupportedSaslMechanismDetails

    Returns $true if Root DSE data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSupportedSaslMechanismDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $rootDse = $adState.RootDSE
    $saslMechanisms = $rootDse.SupportedSASLMechanisms
    $mechanismCount = if ($saslMechanisms) { ($saslMechanisms | Measure-Object).Count } else { 0 }

    $testResult = $true

    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total SASL Mechanisms | $mechanismCount |`n"

    if ($mechanismCount -gt 0) {
        $result += "`n**Supported SASL Mechanisms:**`n`n"
        $result += "| Mechanism | Description | Security Level |`n"
        $result += "| --- | --- | --- |`n"

        foreach ($mechanism in $saslMechanisms) {
            switch ($mechanism) {
                'GSSAPI' { $desc = 'Kerberos authentication'; $level = 'High' }
                'GSS-SPNEGO' { $desc = 'Negotiate (Kerberos/NTLM)'; $level = 'Medium-High' }
                'EXTERNAL' { $desc = 'External authentication (TLS certs)'; $level = 'High' }
                'DIGEST-MD5' { $desc = 'Digest authentication'; $level = 'Low' }
                default { $desc = 'Unknown mechanism'; $level = 'Unknown' }
            }
            $result += "| $mechanism | $desc | $level |`n"
        }
    }

    $testResultMarkdown = "Active Directory SASL mechanism details have been retrieved. These mechanisms determine available authentication protocols.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


