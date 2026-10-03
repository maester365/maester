---
sidebar_label: AD Connection Troubleshooting
sidebar_position: 3
title: Active Directory Connection Troubleshooting
---

## Overview
- Maester uses System.DirectoryServices.Protocols.LdapConnection for cross-platform AD connectivity.
- TLS is required for all AD connections.

## Understanding TLS Modes
- The -ActiveDirectoryTlsMode parameter supports three values: Auto, Ldaps, StartTls.
- Auto (default): Tries LDAPS (port 636) first, then StartTLS (port 389) on Windows. On Linux/macOS, only tries LDAPS.
- Ldaps: Uses LDAPS on port 636 only.
- StartTls: Uses StartTLS on port 389 only.
- Auto mode adapts to the platform due to a known .NET limitation.

## Certificate Issues on the Domain Controller
- Common symptoms: connection fails with certificate, trust, validation, expired, or chain errors.
- Troubleshooting steps:
  1. Verify the DC has a valid server-authentication certificate installed.
  2. Verify the certificate SAN includes the DC's FQDN.
  3. Verify the certificate is not expired.
  4. On the client, verify the DC's certificate chain is trusted.
  5. For test environments only: -SkipCertificateCheck can be used with New-MtLdapConnection directly (not available on Connect-Maester).
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
