`SIDHistory` is commonly used during migrations so users can retain access to resources secured with legacy SIDs. Long-term SID history can create unnecessary complexity and unintended access paths.

- **Migration artifact detection**: Identifies users that may still carry legacy identities
- **Trust boundary review**: Helps spot cross-domain access dependencies
- **Permission cleanup**: Supports least-privilege remediation after migrations

#### Security Recommendation

- Review users with `SIDHistory` to confirm ongoing business need
- Remove unnecessary SID history entries after resource migration is complete
- Pay special attention to SIDs originating from external or less-trusted domains

#### How the Test Works

This test counts user objects where the `SIDHistory` attribute contains one or more values.

#### Related Tests

- `Test-MtAdUserNonStandardPrimaryGroupCount` - Finds other migration or provisioning anomalies
- `Test-MtAdUserAdminCountCount` - Helps prioritize review of privileged accounts

#### Related links

- [Microsoft Defender for Identity: Unsecure SID History attributes](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#unsecure-sid-history-attributes)
- [ANSSI Active Directory checkpoints: Accounts or groups with SID history set](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_sidhistory_present)
