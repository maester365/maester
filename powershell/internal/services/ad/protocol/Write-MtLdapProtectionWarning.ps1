function Write-MtLdapProtectionWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Server,

        [int]$Port,

        [Parameter(Mandatory)]
        [string]$AuthType,

        [switch]$ForceUnsigned
    )

    $safeServer = $Server -replace '(?i)(ldap(?:s)?://)?[^/\s:@]+:[^@\s/]+@', '$1<redacted>@'
    $warning = "INSECURE LDAP to '$safeServer' on port ${Port}: TLS and SASL sealing are explicitly disabled. LDAP queries and results have no confidentiality protection and may be read on the network. "
    if ($AuthType -eq 'Basic') {
        $warning += 'Basic/simple bind sends the username and password in plaintext to a server that this connection does not authenticate. LDAP messages are unsigned, have no integrity protection, and may be altered. '
    } else {
        $warning += switch ($AuthType) {
            'Kerberos' { 'Kerberos exchanges tickets and authenticators, not the plaintext password. ' }
            'Ntlm' { 'NTLM exchanges challenge-response tokens, not the plaintext password; these tokens can be relayed or attacked by offline password cracking. ' }
            default { 'Negotiate may select Kerberos or NTLM; it exchanges authentication tokens, not the plaintext password. NTLM tokens can be relayed or attacked by offline password cracking. ' }
        }
        if ($ForceUnsigned.IsPresent) {
            $warning += 'SASL signing is explicitly disabled: LDAP messages have no integrity protection and may be altered or relayed. '
        } else {
            $warning += 'SASL signing is left to platform policy and is not required by Maester. Signing, if negotiated, protects message integrity, not confidentiality. '
        }
    }
    $warning += 'Use only in isolated test environments. These settings affect LDAP, not SMB/SYSVOL or WinRM. Every new bind repeats this warning and, for Basic, sends the password again.'
    Write-Warning $warning
}
