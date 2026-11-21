Stale enabled computer accounts represent a significant security risk in Active Directory. These are computer accounts that remain enabled but have not authenticated to the domain for `MaximumInactiveDays` (default 180) or more.

**Security Risks:**
- **Attack Vector**: Stale accounts can be compromised and reactivated by attackers
- **Lateral Movement**: Compromised stale accounts provide footholds for lateral movement
- **Credential Theft**: May have weak or unchanged passwords
- **Shadow IT**: May indicate forgotten or unauthorized systems
- **Compliance Issues**: Violates security policies requiring regular account review

**Common Causes:**
- Decommissioned systems that were never disabled
- Virtual machines that were deleted but not removed from AD
- Test systems that are no longer in use
- Hardware refreshes where old accounts remain

#### Control Type

**Detective**

#### Security Recommendation

1. **Regular Review Process**:
   - Quarterly review of stale enabled computers
   - Document business justification for exceptions
   - Automate detection and reporting

2. **Remediation Actions**:
   - Disable computers after 90-180 days of inactivity
   - Delete disabled computers after additional review period
   - Verify with system owners before deletion

3. **Preventive Measures**:
   - Implement automated provisioning/deprovisioning
   - Use computer account lifecycle management
   - Regular audits of computer account creation

#### How the Test Works

This test identifies enabled computers that:
- Have never logged on, OR
- Have not logged on for `MaximumInactiveDays` (default 180) or more

Provides counts and lists affected computers.

The retired **AD-COMP-02 — Computer dormant count should be retrievable** is consolidated into [AD-DCOMP-06 — No enabled computers should be stale beyond the configured threshold](https://maester.dev/docs/tests/AD-DCOMP-06). Its former default was 90 days; set `MaximumInactiveDays` to `90` to retain that threshold. The canonical default remains 180 days.

#### Configure the Inactivity Threshold

The default threshold is 180 days. Set `MaximumInactiveDays` in `maester-config.json` to use another value from 1 to 3650 days. Maester reuses this test setting on `Invoke-Maester` runs.

```json
{
  "TestSettings": [
    {
      "Id": "AD-DCOMP-06",
      "Parameters": {
        "MaximumInactiveDays": 90
      }
    }
  ]
}
```

This check is the canonical inventory of stale enabled computer accounts. Findings return **Investigate**; a clean inventory returns **Passed**.

#### Related Tests

- [AD-COMP-01 — Computer disabled count should be retrievable](https://maester.dev/docs/tests/AD-COMP-01): Counts disabled computer accounts, complementing this check of enabled accounts with stale or missing logon data.
- [AD-USER-02 — Dormant enabled user count should be retrievable](https://maester.dev/docs/tests/AD-USER-02): Reviews stale enabled user accounts, a separate account population with a similar lifecycle concern.

#### Related links

- [ANSSI Active Directory checkpoints: Inactive servers](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_password_change_inactive_servers)

<!--- Results --->
%TestResult%
