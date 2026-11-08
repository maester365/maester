function Test-MtAdSupportedSaslMechanismCount {
    <#
    .SYNOPSIS
    Retrieves the count of supported SASL mechanisms in Active Directory.

    .DESCRIPTION
    Simple Authentication and Security Layer (SASL) mechanisms define the
    authentication protocols supported by Active Directory. The Root DSE
    (Directory Service Agent) publishes the supported SASL mechanisms which
    clients use to negotiate authentication.

    Common SASL mechanisms include:
    - GSSAPI: Kerberos-based authentication (most secure)
    - GSS-SPNEGO: Negotiate authentication
    - EXTERNAL: External authentication
    - DIGEST-MD5: Digest authentication

    Understanding supported mechanisms helps assess authentication capabilities
    and potential security implications.

    .EXAMPLE
    Test-MtAdSupportedSaslMechanismCount

    Returns $true if Root DSE data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSupportedSaslMechanismCount
    #>
    [MaesterTest(
        Id = 'AD-ROOTDSE-01',
        Title = 'Advertised SASL mechanism count and details should be investigated',
        Product = 'ad',
        Feature = 'directory-configuration',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdSupportedSaslMechanismCount"

    $adState = Get-MtADDomainState -Categories @('Domain')

    if ($null -eq $adState) {
        throw 'Active Directory domain state was not returned.'
    }

    $rootDse = $adState.RootDSE
    if ($null -eq $rootDse) { throw 'LDAP RootDSE was not returned.' }
    $saslMechanisms = $rootDse.SupportedSASLMechanisms
    $mechanismCount = if ($saslMechanisms) { ($saslMechanisms | Measure-Object).Count } else { 0 }

    $testResult = $true

    $result = "| Property | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Supported SASL Mechanisms Count | $mechanismCount |" + "`n"

    $result += "`n| Advertised mechanism | Description |`n| --- | --- |`n"
    foreach ($mechanism in $saslMechanisms) {
        $description = switch ($mechanism) {
            'GSSAPI' { 'Kerberos (GSSAPI)' }
            'GSS-SPNEGO' { 'Negotiation (Kerberos or NTLM)' }
            'EXTERNAL' { 'External authentication' }
            'DIGEST-MD5' { 'Digest; advertised by Windows Server 2003 and later' }
            default { 'Mechanism advertised by this domain controller' }
        }
        $result += "| $mechanism | $description |`n"
    }

    $testResultMarkdown = "The connected domain controller advertises these SASL mechanisms in RootDSE. Advertisement does not establish whether a bind succeeds or which clients use each mechanism.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
