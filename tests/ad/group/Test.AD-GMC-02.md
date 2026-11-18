- Understanding the types of objects that can be group members helps assess Active Directory security posture:
- **Security Principal Types**: Groups can contain users, groups, computers, and foreign security principals
- **Nested Groups**: Groups containing other groups create inheritance chains that can be complex to audit
- **Computer Membership**: Computers in groups may indicate service accounts or special access requirements
- **Foreign Principals**: External domain members represent trust relationships that extend beyond the local domain

#### Control Type

**Operational**

#### Security Recommendation

- Monitor group membership composition:
- Nested group membership can create unexpected access paths
- Foreign security principals indicate cross-domain access that should be regularly reviewed
- Computer accounts in sensitive groups may indicate misconfigurations

#### How the Test Works

- This test analyzes group membership across Active Directory and:
- Identifies distinct object classes among group members
- Counts unique account types (user, group, computer, foreignSecurityPrincipal)
- Provides visibility into membership composition

The test analyzes all collected groups, deduplicates members by SID (or distinguished name when SID is unavailable), and includes the account-type breakdown. This complete membership scan is opt-in (`LongRunning`); the test does not truncate to the first 50 groups. Group-query failures are errors, not a successful empty inventory, and the protocol connection is disposed even on failure.

#### Related Tests

- **AD-GMC-06 — Foreign SID principals count should be investigated** — `Test-MtAdGroupMemberForeignSidCount` — Inventories direct foreign domain-account SIDs separately.

<!--- Results --->
%TestResult%
