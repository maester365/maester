---
title: Active Directory Connection Troubleshooting
description: "Troubleshoot Active Directory connections, TLS modes, unencrypted LDAP options, certificate problems, and verbose diagnostics."
sidebar:
  label: AD Connection Troubleshooting
  order: 3
---

## Overview
- Maester uses System.DirectoryServices.Protocols.LdapConnection for cross-platform AD connectivity.
- TLS is used by default for AD connections. Explicit options can disable LDAP TLS for isolated troubleshooting, with significant security risks.

## Understanding TLS Modes
- The -ActiveDirectoryTlsMode parameter supports four values: Auto, Ldaps, StartTls, None.
- Auto (default): Tries LDAPS (port 636) first, then StartTLS (port 389) on Windows. On Linux/macOS, only tries LDAPS.
- Ldaps: Uses LDAPS on port 636 only.
- StartTls: Uses StartTLS on port 389 only.
- None: Requires the explicit lab-only opt-ins described below; disables TLS and SASL sealing.
- Auto mode adapts to the platform due to a known .NET limitation.

## Unencrypted LDAP (Lab Use Only)

`None` is an explicit opt-out from TLS, not a troubleshooting default. `Auto`, `Ldaps`, and `StartTls` are unchanged; Maester does not write SASL signing or sealing options on TLS connections.

| Protection | What it provides | What happens when disabled |
|---|---|---|
| TLS | Confidentiality and integrity for the LDAP connection, plus server certificate authentication | LDAP traffic is not protected by TLS. With Basic authentication, the password is sent on the wire and the server is not authenticated. |
| SASL sealing | Confidentiality for SASL-protected LDAP traffic | Directory queries and results can be read by an observer. |
| SASL signing | Integrity, but not encryption | Directory queries and results can be tampered with in transit. |

The following switches require `-ActiveDirectoryTlsMode None` and `-ActiveDirectoryForceUnencrypted` together:

- `-ActiveDirectoryForceUnencrypted` explicitly disables LDAP TLS and SASL sealing.
- `-ActiveDirectoryForceUnsigned` additionally disables SASL signing of LDAP messages for Negotiate, Kerberos, or NTLM authentication. These mechanisms exchange authentication tokens, not clear-text passwords. NTLM challenge-response material can be relayed or subjected to offline password cracking; disabling signing also removes LDAP message integrity protection. This option is separate from `-ActiveDirectoryAllowPlaintextPassword` and cannot be combined with Basic authentication.
- `-ActiveDirectoryAllowPlaintextPassword` is a separate acknowledgement for Basic/simple bind, which sends the password without TLS. It requires `-ActiveDirectoryServer` to be explicitly set, as well as `None` and `ForceUnencrypted`. Basic does not use SASL signing or sealing options. Naming a server explicitly does not authenticate that server when TLS is off.

These settings are strongly discouraged and intended only for controlled lab testing. Domain controllers can reject unencrypted binds, including with `strongerAuthRequired` or signing policy. Maester fails closed if the client provider cannot apply the requested signing/sealing settings or if policy re-enables signing that was explicitly disabled. Standard Linux OpenLDAP with .NET 8 or .NET 10 does not support the required signing/sealing setters, so token-based unencrypted mode fails clearly there. On Windows, `LDAPClientIntegrity=1` can cause Negotiate signing to be re-enabled; `ForceUnsigned` therefore fails until the client policy permits unsigned LDAP. Maester does not change host or domain-controller policy automatically.

Maester emits a warning naming the target before each risky bind. Reused state, reprobes, or reconstructed connections create fresh binds, so warnings recur and Basic sends the password again. These LDAP options do not disable protection for SMB/SYSVOL or WSMan.

Token-based authentication with signing and sealing explicitly disabled:

```powershell
Connect-Maester -Service ActiveDirectory -ActiveDirectoryServer 'dc01.example.com' -ActiveDirectoryTlsMode None -ActiveDirectoryForceUnencrypted -ActiveDirectoryForceUnsigned
```

Basic/simple bind with its separate plaintext-password acknowledgement:

```powershell
$credential = Get-Credential
Connect-Maester -Service ActiveDirectory -ActiveDirectoryServer 'dc01.example.com' -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode None -ActiveDirectoryForceUnencrypted -ActiveDirectoryAllowPlaintextPassword -ActiveDirectoryCredential $credential
```

Do not use these examples against production systems or untrusted networks.

## Certificate Issues on the Domain Controller
- Common symptoms: connection fails with certificate, trust, validation, expired, or chain errors.
- Troubleshooting steps:
  1. Verify the DC has a valid server-authentication certificate installed.
  2. Verify the certificate SAN includes the DC's FQDN.
  3. Verify the certificate is not expired.
  4. On the client, verify the DC's certificate chain is trusted.
  5. For test environments only: use `Connect-Maester -Service ActiveDirectory -ActiveDirectorySkipCertificateCheck` to bypass certificate validation.
- If LDAPS fails but StartTLS succeeds, the DC's LDAPS certificate (port 636) is misconfigured — check the certificate on the DC.

## Linux and macOS StartTLS Limitation
- The known upstream .NET bugs ([dotnet/runtime#96988](https://github.com/dotnet/runtime/issues/96988) and [dotnet/runtime#110391](https://github.com/dotnet/runtime/issues/110391)) affect StartTLS on these platforms.
- StartTransportLayerSecurity() fails on Linux/macOS regardless of certificate configuration.
- Recommendation: Use Ldaps mode or Auto mode on Linux/macOS (Auto will use LDAPS only).
- Note: ldapsearch -ZZ may work on the same host — this is because the bug is in .NET's managed-to-native interop, not in OpenLDAP.

## Using Verbose Output for Diagnostics
- Use -Verbose with Connect-Maester or Connect-MtAdTarget to get detailed diagnostics.
- Logged information at each stage:
  - Resolved target server
  - TLS mode being attempted
  - StartTLS negotiation status
  - Bind success/failure
  - Certificate-specific guidance messages

## Forcing a Specific TLS Mode
- You can bypass Auto mode by explicitly setting -ActiveDirectoryTlsMode:
  ```powershell
  Connect-Maester -Service ActiveDirectory -ActiveDirectoryTlsMode Ldaps
  Connect-Maester -Service ActiveDirectory -ActiveDirectoryTlsMode StartTls
  ```
