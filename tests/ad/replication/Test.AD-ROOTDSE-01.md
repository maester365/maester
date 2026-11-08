Inventories the **count and individual descriptions** of SASL mechanism names advertised by the connected domain controller's LDAP RootDSE.

An advertised mechanism is not proof that a client successfully binds with it, that clients use it, or that a server policy enables a particular authentication path. DIGEST-MD5 may be advertised by Windows Server 2003 and later; its presence alone is not evidence of insecure use.

#### Remediation action

1. Review the advertised mechanisms against the domain's authentication requirements.
2. To assess real authentication behavior, review domain controller policy and relevant authentication logs separately; do not infer bind success from this inventory.

#### Related links

* [Microsoft ADTS: RootDSE supportedSASLMechanisms](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/96f7b086-1ca3-4764-9a08-33f8f7a543db)

<!--- Results --->
%TestResult%
