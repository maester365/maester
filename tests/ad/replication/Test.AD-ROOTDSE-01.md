Inventories the **count and individual descriptions** of SASL mechanism names advertised by the connected domain controller's LDAP RootDSE.

#### Control Type

**Operational**

#### Security Recommendation

Compare the names advertised on this connection with the organization's approved authentication mechanisms, then investigate any unexpected entries with domain administrators. There is no universal required list.

#### How the Test Works

The check reads `supportedSASLMechanisms` on the RootDSE of the connected domain controller and reports each advertised name and a count. The advertisement is session-specific: mechanisms can change after TLS negotiation, so this is not an assertion about every connection or DC.

#### Related Tests

- **AD-ROOTDSE-03 — Root DSE should be synchronized** — `Test-MtAdRootDseSynchronizedStatus` — Reviews synchronization separately from advertised mechanisms.

An advertised mechanism is not proof that a client successfully binds with it, that clients use it, or that a server policy enables a particular authentication path. DIGEST-MD5 may be advertised by Windows Server 2003 and later; its presence alone is not evidence of insecure use.

#### Remediation action

1. Review the advertised mechanisms against the domain's authentication requirements.
2. To assess real authentication behavior, review domain controller policy and relevant authentication logs separately; do not infer bind success from this inventory.

#### Related links

* [RFC 4513: SASL mechanism discovery and TLS](https://www.rfc-editor.org/rfc/rfc4513#section-5.2.1.5)
* [Microsoft ADTS: RootDSE supportedSASLMechanisms](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/a98c1f56-8246-4212-8c4e-d92da1a9563b)

<!--- Results --->
%TestResult%
