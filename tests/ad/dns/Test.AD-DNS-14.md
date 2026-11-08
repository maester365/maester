Empty DNS zones (zones with no resource records) may indicate:

- **Incomplete configuration**: Zones created but never populated
- **Abandoned infrastructure**: Services that were planned but never deployed
- **Configuration errors**: Failed zone creation or replication issues
- **Cleanup opportunities**: Removing unused zones reduces complexity

Empty zones add administrative overhead without providing value and may confuse administrators.

#### Control Type

**Detective**

#### Security Recommendation

- Audit empty zones regularly
- Delete zones that are no longer needed
- Document the purpose of any intentionally empty zones
- Investigate unexpected empty zones for potential issues

#### How the Test Works

This test identifies DNS zones that contain zero resource records of any type.

#### Related Tests

- **AD-DNS-01 — DNS zone count should be retrievable** — `Test-MtAdDnsZoneCount` — Counts zones with records.
- **AD-DNS-02 — Zones with only SOA/NS records should be retrievable** — `Test-MtAdDnsZonesWithOnlySoaNs` — Finds zones with only default records.

<!--- Results --->
%TestResult%
