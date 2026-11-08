Understanding which groups have members versus empty groups provides useful inventory for Active Directory utilization and group lifecycle reviews. Member presence alone does not show whether the group grants access, whether its membership is appropriate, or whether the group is still needed:

- **Group Hygiene**: Empty groups may represent unused or forgotten groups that could be cleaned up
- **Access Management**: Groups with members are candidates for checking actual permissions and application dependencies
- **Audit Scope**: Prioritize groups using resource-permission evidence, not membership counts alone
- **Directory Cleanup**: Identify candidates for decommissioning or consolidation

#### Control Type

**Operational**

#### Security Recommendation

Regularly review group membership to identify:
- Empty groups that might be retired after owner and dependency review
- Groups with unexpectedly few members (potential misconfigurations)
- Groups with excessive members (may need splitting for better access control)

#### How the Test Works

This complete visible-group member scan is `LongRunning`; select its exact ID or use `-IncludeLongRunning` to run it. Failed member reads are reported as errors and the LDAP connection is disposed even when a read fails; the scan does not silently stop at 50 groups.

This test analyzes Active Directory groups and counts:
- Total number of groups in the directory
- Number of groups that contain at least one member
- Percentage of groups with members
- Empty groups (for cleanup candidates)

The check analyzes every collected group and reports the complete group count.

Results are an **Investigate** inventory, not a compliance verdict. Review empty groups with their owners and check actual resource permissions and application dependencies before cleanup.

#### Related Tests

- **AD-GMC-02 — Distinct account types of members count should be retrievable** — `Test-MtAdGroupMemberAccountTypeCount` — Summarizes distinct member types.
- **AD-GMC-04 — Trust members count should be investigated** — `Test-MtAdGroupMemberTrustCount` — Identifies direct foreign-domain group members for review.

<!--- Results --->
%TestResult%
