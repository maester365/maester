Strong SID filtering is a critical security control for inter-forest trusts:

- **Prevents Privilege Escalation**: Blocks malicious SID history from being honored across trust boundaries
- **Limits Blast Radius**: Contains the impact of a compromised external domain
- **Security Best Practice**: Microsoft recommends SID filtering for all external trusts
- **Compliance Requirement**: Many security frameworks require SID filtering on external trusts

Without strong SID filtering, an attacker who compromises a domain in a trusting forest could inject SIDs from the trusted forest's privileged groups (like Domain Admins or Enterprise Admins) into their own account, effectively gaining privileged access across the trust boundary.

#### Control Type

**Operational**

#### Security Recommendation

- **Enable SID Filtering**: Enable SID filtering (quarantine) on ALL external trusts
- **Disable SID History**: Disable SID history on ALL forest trusts
- **Audit Regularly**: Regularly verify that external trusts remain quarantined and forest trusts do not have SID history enabled
- **Document Exceptions**: If strong SID filtering cannot be enabled, document the risk and compensating controls
- **Use Forest Trusts**: When possible, use forest trusts instead of external trusts as they provide better security controls
- **Monitor Changes**: Alert on any changes to trust SID filtering status

#### How the Test Works

This test derives trust classification and SID filtering status from the `trustAttributes` LDAP attribute and `trustType`:

- **External trusts**: `trustType` in `1,2` and `trustAttributes` does not have `FOREST_TRANSITIVE` (`0x8`) or `WITHIN_FOREST` (`0x20`)
- **Forest trusts**: `trustAttributes` has `FOREST_TRANSITIVE` (`0x8`)
- **Strong external trusts**: `QUARANTINED_DOMAIN` (`0x4`) is set
- **Strong forest trusts**: `TREAT_AS_EXTERNAL` (`0x40`) is not set (SID history disabled)

The test returns:
- Total count of trusts
- Count of external/forest trusts evaluated
- Count of trusts with strong SID filtering
- Count of trusts with weak SID filtering

#### Related Tests

- `Test-MtAdTrustNonQuarantinedDetails` - Lists specific trusts without SID filtering
- `Test-MtAdTrustInterForestCount` - Identifies external trusts that should be quarantined
- `Test-MtAdTrustDetails` - Shows quarantine status for all trusts

#### Related links

- [Microsoft Learn: Security considerations for trusts](https://learn.microsoft.com/previous-versions/windows/it-pro/windows-server-2003/cc755321%28v=ws.10%29)
- [ANSSI Active Directory checkpoints: Unfiltered outbound domain trust relationship](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_trusts_domain_notfiltered)
