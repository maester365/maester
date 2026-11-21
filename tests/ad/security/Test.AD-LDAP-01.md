Reports the available evidence for LDAP encryption, signing, and Kerberos authentication from Maester's cached Active Directory domain state.

This informational check always requests investigation. It reports the **domain-state collection connection**, which can be a separate connection from the initial `Connect-Maester` bind, and the SASL mechanisms advertised by that connection's domain controller. It does not probe alternative protocols, read DC enforcement policies, or assess every domain controller. Existing SASL inventories **AD-ROOTDSE-01** and **AD-ROOTDSE-02** enumerate mechanisms; this check adds connection-state context and explicitly identifies gaps in security evidence.

The report has two sections:

1. **Connection actually used:** one connection assessment and three components that apply **together (AND)**: transport, certificate validation, and authentication. An Undesirable component takes precedence; otherwise missing evidence makes the assessment Unknown, an authentication choice needing attention makes it Review, and positive evidence for all three makes it Good. This assessment describes recorded configuration, not an independent audit of platform trust settings or domain-wide compliance.
2. **Alternative connection options:** separate tables for **transport choices (OR)** and **authentication choices (OR)**. Choose one of each: **(LDAPS OR StartTLS) AND (an authentication method)**. A transport or authentication capability alone does not prove every combination will work with your credentials, certificates, DNS/SPNs, and policies. Alternatives without recorded results remain unknown. Auto mode may have attempted and failed LDAPS before selecting StartTLS; attempt history is not included in the cached evidence.

Each row includes an indicator:

| Indicator | Interpretation |
| --- | --- |
| Good | Positive evidence for that particular property or a secure connection option. It does not certify the whole connection or domain. |
| Review | A limitation or authentication choice warrants investigation, such as Negotiate fallback or Basic authentication even when protected by TLS. |
| Undesirable | Avoid this production configuration: no TLS, certificate-validation bypass, or legacy NTLM authentication. |
| Unknown | Evidence is missing, not collected, or the alternative's result was not recorded. |

The check remains informational and always returns **Investigate**. Indicators help interpret observations; they do not add a scored compliance assertion. In particular, a Good transport row does not cancel an Undesirable certificate-validation row; their combined assessment is Undesirable.

Interpret the evidence separately:

- **Encryption:** recorded `Ldaps` or `StartTls` demonstrates TLS use for the collection connection and observed support for that mode. The other TLS mode remains unknown. `None` means no TLS, not necessarily no encryption: SASL sealing is not collected. The TLS version, cipher suite, and DC encryption-enforcement policy are not collected.
- **LDAPS versus StartTLS:** LDAPS establishes TLS before LDAP traffic; StartTLS upgrades the LDAP connection to TLS before authentication in Maester. Both receive a Good encryption indicator when recorded as used. StartTLS is not inherently weaker once TLS is established; this check does not infer handshake quality or insecure fallback from the transport name alone.
- **Certificate validation:** a recorded certificate-check bypass means TLS use does not establish trusted server identity or exclude an active interceptor. The transport row explicitly qualifies this limitation. Without a requested bypass, platform default validation applies; this report does not independently audit certificates or the host's validation configuration.
- **Signing:** TLS provides transport integrity. Separate SASL signing/sealing state, support, and DC LDAP signing-enforcement policies are not collected. A TLS bind neither proves nor disproves DC signing enforcement.
- **Kerberos:** an explicit `Kerberos` bind mode is reported as such, and the capability table prefers a successfully recorded explicit bind mode over an advertisement. `Negotiate` can select Kerberos or NTLM, so actual Kerberos use remains unknown. Without an explicit Kerberos bind, a `GSSAPI` advertisement indicates capability only, not successful Kerberos authentication or Kerberos-only enforcement. A missing advertisement is not proof that Kerberos is unsupported.

**Unknown / not collected** means the current data source cannot answer the question. It does not mean disabled, unsupported, compliant, or noncompliant. This inventory has no framework mapping because reading the evidence is not proof that a security control is implemented.

SASL signing/sealing state and effective DC enforcement settings are listed as a single configuration-evidence limitation, not as alternative connection options. Maester can collect configuration through a narrowly scoped, cached read-only management helper, as existing DC SMB checks do. No LDAP-policy collector currently supplies this check. Reading GPO links or advertised SASL mechanisms alone would not prove a DC's effective configuration. Such a collector could target just the contacted DC without testing every protocol against every DC; a domain-wide conclusion would require explicit coverage of the relevant DCs' configuration.

#### Remediation action

There is no automatic pass/fail remediation for this informational check.

1. Review **Connection actually used** and its combined assessment first. Address Undesirable components and investigate Review components. Then review the separate transport and authentication tables under **Alternative connection options**. Do not extrapolate one connection's evidence to all clients or domain controllers.
2. Where TLS is absent or validation is bypassed, review the DC's [LDAPS certificate configuration](https://learn.microsoft.com/windows-server/identity/ad-ds/configure-ldap-signing-certificates) and the trust configuration on the Maester host. Use LDAPS or StartTLS with certificate validation for production collection.
3. To investigate signing enforcement, inspect the effective **Domain controller: LDAP server signing requirements** policies and Directory Service events using Microsoft's [LDAP signing guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/ldap-signing). Evaluate client compatibility before changing policies. This check does not perform an unsigned bind or transmit credentials without TLS.
4. To verify Kerberos rather than Negotiate fallback, review the host's Kerberos prerequisites, DNS/SPNs, and authentication telemetry. An explicit `-ActiveDirectoryAuthMode Kerberos` connection can provide bind-mode evidence on a later run; it does not establish a DC-wide Kerberos-only policy.
5. After any authorized configuration change, start a new Maester session and run the check again so the report uses a new snapshot rather than bypassing the session cache.

#### Related links

- [LDAP signing overview for Active Directory](https://learn.microsoft.com/windows-server/identity/ad-ds/ldap-signing)
- [Configure certificates for LDAP over SSL](https://learn.microsoft.com/windows-server/identity/ad-ds/configure-ldap-signing-certificates)
- [Microsoft Negotiate and Kerberos/NTLM selection](https://learn.microsoft.com/windows/win32/secauthn/microsoft-negotiate)
- [Active Directory SASL authentication](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/989e0748-0953-455d-9d37-d08dfbf3998b)
- [Planned domain-controller configuration-state checks](https://maester.dev/docs/advanced/domain-controller-configuration-state)

<!--- Results --->
%TestResult%
