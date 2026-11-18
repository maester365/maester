User account SPNs with non-FQDN hosts can cause:

- **Authentication failures**: Kerberos may fail to resolve short names
- **Cross-domain issues**: Short names may be ambiguous across domain trusts
- **Service disruptions**: Applications may fail to authenticate
- **Configuration drift**: Indicates inconsistent SPN management

Since user accounts with SPNs are already high-value targets, ensuring proper FQDN configuration is essential.

#### Control Type

**Operational**

#### Security Recommendation

Review and fix non-FQDN user SPNs:
- Update SPNs to use fully qualified domain names
- Establish SPN registration standards
- Use FQDNs consistently for all service principal names
- Consider this as part of a migration to gMSAs

#### How the Test Works

This test parses user SPNs and checks whether the host portion contains a dot as a simple FQDN-format proxy. Short names are not necessarily invalid and require workload-specific review.

#### Related Tests

- **AD-SPN-05 — Computer SPN non-FQDN hosts should be investigated** — `Test-MtAdComputerSpnNonFqdnHosts` — Reviews computer SPN hosts.
- **AD-SPN-06 — User SPN total count should be investigated** — `Test-MtAdUserSpnTotalCount` — Inventories user SPNs.

<!--- Results --->
%TestResult%
