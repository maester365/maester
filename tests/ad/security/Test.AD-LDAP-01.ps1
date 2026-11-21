function Test-MtAdLdapConnectionSecurity {
    <#
    .SYNOPSIS
    Reports LDAP encryption, signing, and Kerberos evidence for review.

    .DESCRIPTION
    Uses cached Active Directory domain state to report the collection connection's
    TLS and authentication modes separately from the contacted domain controller's
    observed or advertised capabilities. The connection's transport, certificate
    validation, and authentication apply together (AND). Alternative transports
    and alternative authentication methods are separate choices (OR).
    Signing, sealing, and domain-controller enforcement are not collected.
    This inventory does not assess domain-wide compliance or probe other modes.
    #>
    [MaesterTest(
        Id                 = 'AD-LDAP-01',
        Title              = 'LDAP encryption, signing, and Kerberos evidence should be investigated',
        Product            = 'ad',
        Feature            = 'directory-configuration',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'Info',
        Mitre              = 'None',
        Service            = 'ActiveDirectory',
        Permission         = 'ActiveDirectory:Ldap:domainDNS:ReadProperty',
        Author             = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState -Categories Domain
    if ($null -eq $adState) {
        throw 'Active Directory domain state could not be retrieved for the LDAP security report.'
    }

    $evidence = $adState.ProtocolEvidence
    $tlsMode = [string]$evidence.TlsMode
    $authenticationMode = [string]$evidence.AuthenticationMode
    $mechanisms = @($adState.RootDSE.SupportedSaslMechanisms | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $tlsEncryption = switch ($tlsMode) {
        'Ldaps' { 'Enabled (LDAPS; TLS established before LDAP traffic)' }
        'StartTls' { 'Enabled (StartTLS; LDAP connection upgraded to TLS before authentication)' }
        'None' { 'Disabled (no TLS); SASL sealing is unknown' }
        default { 'Unknown / not collected' }
    }
    $certificateValidation = if ($tlsMode -notin 'Ldaps', 'StartTls') {
        'Not applicable or unknown (no recorded TLS connection)'
    } elseif ($null -eq $evidence.SkipCertificateCheck) {
        'Unknown / not collected'
    } elseif ($evidence.SkipCertificateCheck) {
        'Bypassed; TLS use does not establish trusted server identity'
    } else {
        'Bypass not requested; platform default validation applies'
    }
    if ($tlsMode -in 'Ldaps', 'StartTls' -and $evidence.SkipCertificateCheck) {
        $tlsEncryption += '; server identity unverified, so an active interceptor is not excluded'
    }
    $kerberosAuthentication = switch ($authenticationMode) {
        'Kerberos' { 'Explicit Kerberos bind mode recorded; no negotiated-mechanism telemetry' }
        'Negotiate' { 'Unknown; Negotiate can select Kerberos or NTLM' }
        'Ntlm' { 'Kerberos not selected (NTLM bind mode recorded)' }
        'Basic' { 'Kerberos not selected (Basic bind mode recorded)' }
        default { 'Unknown / not collected' }
    }
    $kerberosSupport = if ($authenticationMode -eq 'Kerberos') {
        'Observed: successful explicit Kerberos bind mode; no negotiated-mechanism telemetry'
    } elseif ($mechanisms -contains 'GSSAPI') {
        'Advertised (GSSAPI); does not prove Kerberos use or enforcement'
    } else {
        'Unknown; GSSAPI advertisement not available, not proof of unsupported Kerberos'
    }
    $tlsIndicator = switch ($tlsMode) {
        { $_ -in 'Ldaps', 'StartTls' } { 'Good' }
        'None' { 'Undesirable' }
        default { 'Unknown' }
    }
    $certificateIndicator = if ($tlsMode -notin 'Ldaps', 'StartTls' -or $null -eq $evidence.SkipCertificateCheck) {
        'Unknown'
    } elseif ($evidence.SkipCertificateCheck) { 'Undesirable' } else { 'Good' }
    $authenticationIndicator = switch ($authenticationMode) {
        'Kerberos' { 'Good' }
        'Negotiate' { 'Review' }
        'Ntlm' { 'Undesirable' }
        'Basic' { 'Review' }
        default { 'Unknown' }
    }
    $ldapsSupport = if ($tlsMode -eq 'Ldaps') { 'Observed: successful LDAPS collection connection' } else { 'Unknown / not recorded; a prior attempt may have failed during Auto selection' }
    $startTlsSupport = if ($tlsMode -eq 'StartTls') { 'Observed: successful StartTLS collection connection' } else { 'Unknown / not recorded; alternative-mode attempt history is unavailable' }
    $negotiateSupport = if ($authenticationMode -eq 'Negotiate') {
        'Observed: successful Negotiate bind; underlying Kerberos or NTLM selection is unverified'
    } elseif ($mechanisms -contains 'GSS-SPNEGO' -or $mechanisms -contains 'GSS_SPNEGO') {
        'Advertised (SPNEGO); Kerberos or NTLM selection depends on client and server configuration'
    } else { 'Unknown; SPNEGO advertisement not available' }

    $connectionIndicator = if ('Undesirable' -in $tlsIndicator, $certificateIndicator, $authenticationIndicator) {
        'Undesirable'
    } elseif ('Unknown' -in $tlsIndicator, $certificateIndicator, $authenticationIndicator) {
        'Unknown'
    } elseif ($authenticationIndicator -eq 'Review') { 'Review' } else { 'Good' }
    $connectionSummary = switch ($connectionIndicator) {
        'Undesirable' { 'Avoid the recorded configuration for production; review the component marked Undesirable.' }
        'Unknown' { 'There is insufficient evidence to assess the complete connection combination.' }
        'Review' { 'TLS is recorded and certificate-validation bypass was not requested; the authentication choice needs review.' }
        'Good' { 'TLS is recorded, certificate-validation bypass was not requested, and an explicit Kerberos bind mode was selected.' }
    }
    if ($tlsMode -eq 'None') {
        $connectionSummary += ' No TLS does not itself prove absent SASL encryption.'
    }
    $connectionRows = @(
        @{ Property = 'Transport used'; Indicator = $tlsIndicator; Evidence = $tlsEncryption }
        @{ Property = 'Certificate validation'; Indicator = $certificateIndicator; Evidence = $certificateValidation }
        @{ Property = 'Authentication used'; Indicator = $authenticationIndicator; Evidence = $kerberosAuthentication }
    )
    $transportRows = @(
        @{ Property = 'LDAPS support'; Indicator = $(if ($tlsMode -eq 'Ldaps') { 'Good' } else { 'Unknown' }); Evidence = $ldapsSupport }
        @{ Property = 'StartTLS support'; Indicator = $(if ($tlsMode -eq 'StartTls') { 'Good' } else { 'Unknown' }); Evidence = $startTlsSupport }
    )
    $authenticationRows = @(
        @{ Property = 'Kerberos support'; Indicator = $(if ($kerberosSupport -match '^(Observed|Advertised):?') { 'Good' } else { 'Unknown' }); Evidence = $kerberosSupport }
        @{ Property = 'Negotiate support'; Indicator = $(if ($negotiateSupport -match '^(Observed|Advertised):?') { 'Review' } else { 'Unknown' }); Evidence = $negotiateSupport }
    )
    $context = [ordered]@{
        Server = $evidence.ResolvedServer
        Domain = $evidence.ResolvedDomain
        'Evidence collected' = $evidence.VerifiedAt
    }
    $contextText = foreach ($item in $context.GetEnumerator()) {
        $value = [string]$item.Value
        if ([string]::IsNullOrWhiteSpace($value)) { $value = 'Unknown / not collected' }
        $value = [System.Security.SecurityElement]::Escape($value).Replace('|', '&#124;') -replace '[\r\n]+', ' '
        $value = $value -replace '([\\`*_\[\]()])', '\$1'
        "$($item.Key): $value"
    }
    $sections = @(
        @{ Heading = '#### Connection actually used'; Intro = "**Connection assessment: $connectionIndicator.** $connectionSummary`n`nThese three components apply **together (AND)**; they are not alternative ways to secure the connection."; Column = 'Component (AND)'; Rows = $connectionRows }
        @{ Heading = '#### Alternative connection options'; Intro = 'Choose **one transport (OR)** and **one authentication method (OR)**; the resulting transport and authentication apply **together (AND)**. Evidence for either component alone does not prove every combination will work.'; Subheading = '##### Transport options: choose one (OR)'; Column = 'Transport option (OR)'; Rows = $transportRows }
        @{ Subheading = '##### Authentication options: choose one (OR)'; Column = 'Authentication option (OR)'; Rows = $authenticationRows }
    )
    $result = ($contextText -join '; ') + "`n`n"
    $result += "Evidence describes the cached collection connection and the contacted DC, not every DC in the domain. Good = positive recorded evidence; Review = investigate the authentication choice; Undesirable = avoid this configuration for production; Unknown = insufficient evidence. The check remains informational (Investigate), not a compliance assertion or an independent certificate-validation audit.`n`n"
    foreach ($section in $sections) {
        if ($section.Heading) { $result += "$($section.Heading)`n`n" }
        if ($section.Intro) { $result += "$($section.Intro)`n`n" }
        if ($section.Subheading) { $result += "$($section.Subheading)`n`n" }
        $result += "| $($section.Column) | Indicator | Evidence |`n| --- | --- | --- |`n"
        $rows = foreach ($row in $section.Rows) {
            $value = [string]$row.Evidence
            $indicator = $row.Indicator
            if ([string]::IsNullOrWhiteSpace($value)) {
                $value = 'Unknown / not collected'
                $indicator = 'Unknown'
            }
            # Preserve table structure and render directory-provided text as text.
            $value = [System.Security.SecurityElement]::Escape($value).Replace('|', '&#124;') -replace '[\r\n]+', ' '
            $value = $value -replace '([\\`*_\[\]()])', '\$1'
            "| $($row.Property) | $indicator | $value |"
        }
        $result += ($rows -join "`n") + "`n`n"
    }
    $result += 'LDAPS starts with TLS; StartTLS upgrades LDAP to TLS before the bind in Maester. Both encrypt traffic and provide transport integrity, but trusted server identity is needed to exclude active interception. NTLM is legacy authentication; Basic warrants review even over TLS. Advertisements show possible options, not proof of successful authentication or enforcement. Unknown transport support means there is no recorded result, not that the mode is unsupported.'
    $result += "`n`n**Configuration evidence not collected:** SASL signing/sealing state and effective DC LDAP signing, encryption, or Kerberos-only policies. TLS provides transport integrity but does not establish those policies. Validating them requires an authorized, cached DC-configuration collector; this check neither reads those settings nor probes every DC."

    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
