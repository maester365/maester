Domain administrator accounts with SPNs represent serious Kerberoasting exposure:

- **Maximum privileges**: Domain admins have unrestricted access to the entire domain
- **Golden ticket risk**: Compromising a domain admin can lead to complete domain compromise
- **Service account misuse**: Domain admin accounts should never be used as service accounts
- **Password exposure**: SPNs enable offline password cracking attempts

**Zero domain admin accounts should have SPNs configured.**

#### Control Type

**Preventive**

#### Security Recommendation

If domain admin accounts have SPNs:
- **Immediate action**: Remove all SPNs from domain admin accounts
- **Investigate**: Determine why SPNs were configured
- **Migrate services**: Move services to dedicated service accounts or gMSAs
- **Audit**: Review who has domain admin privileges
- **Monitor**: Implement alerts for SPN changes to privileged accounts

#### How the Test Works

This test identifies the Domain Admins group by its domain SID and RID 512, resolves direct and nested user members plus users whose primary group ID is 512 (not represented by the group's `member` attribute), and checks all of their raw SPNs. RID 500 alone identifies the built-in Administrator account, not the Domain Admins group. An unresolved membership is an error, not a pass.

#### Related Tests

- **AD-SPN-06 — User SPN total count should be investigated** — `Test-MtAdUserSpnTotalCount` — Inventories all user SPNs.
- **AD-SPN-07 — User SPN service class count should be investigated** — `Test-MtAdUserSpnServiceClassCount` — Inventories user-account service classes.

#### Related links

- [Microsoft Defender for Identity: Unsecure account attributes](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#unsecure-account-attributes)
- [ANSSI Active Directory checkpoints: Privileged accounts with SPN](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_spn_priv)

<!--- Results --->
%TestResult%
