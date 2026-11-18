This inventory identifies direct group members whose account SID is in the `S-1-5-21` domain-account namespace and does not match the current domain SID. Such entries can represent principals from other domains or forests and warrant review; they are not, by themselves, evidence of improper access.

- **Trust Relationships**: External domain SIDs indicate trust-based access
- **Cross-Forest Access**: A principal from another forest may appear in a group where a trust permits access
- **Security Auditing**: Review each principal's origin, trust path, group and business need

This test examines group-member SIDs; it does not inspect a member account's `sIDHistory` attribute and does not identify SID history.

#### Control Type

**Operational**

#### Security Recommendation

Monitor and audit foreign account SIDs:
- Verify that trust relationships with external domains are still required
- Be cautious of foreign SIDs in highly privileged groups
- Confirm each SID's source and business purpose before changing memberships

#### How the Test Works

This test analyzes group membership for foreign SIDs by:
- Comparing member SIDs against the current domain SID
- Counting distinct direct member SIDs in the `S-1-5-21` namespace that do not match the current domain SID. Built-in `S-1-5-32` and NT AUTHORITY SIDs are not treated as foreign domain accounts.
- Grouping foreign SIDs by their domain of origin
- Counting unique foreign SID principals

The test analyzes all collected groups and includes group, principal and SID details. The full membership scan is opt-in (`LongRunning`), without a first-50-groups cap. Group query errors are not treated as no findings; the protocol connection is disposed even when a query fails. It does not read `sIDHistory`; the result is an **Investigate** inventory, not a compliance verdict.

#### Related Tests

- **AD-GMC-04 — Trust members count should be investigated** — `Test-MtAdGroupMemberTrustCount` — Reports direct cross-domain group members using the trust-member classification.

<!--- Results --->
%TestResult%
