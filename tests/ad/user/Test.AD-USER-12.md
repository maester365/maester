Ordinary users should use approved primary group RIDs (default 513, Domain Users). Protected identities and built-in RID 500–503 accounts are exempt. Hidden primary group membership can complicate reviews.

#### Control Type

**Detective**

#### Security Recommendation

Review deviations from the approved primary-group RID list with identity owners. Do not change protected or system identities as part of this ordinary-user check.

#### How the Test Works

The test evaluates ordinary users' `primaryGroupId` against `AllowedPrimaryGroupIds` (default 513), excluding protected identities and built-in RID 500–503 users. Primary-group membership is not always visible through the group's ordinary `member` attribute.

#### Related Tests

- **AD-USER-11 — AdminCount users should be reviewed** — `Test-MtAdUserAdminCountCount` — Reviews protected-user markers.
- **AD-USER-13 — Users should not retain unapproved SID history** — `Test-MtAdUserSidHistoryCount` — Reviews migration-related identity attributes.

#### Remediation action
1. Validate required group membership, then restore an approved primary group through [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Add documented legitimate RID exceptions to `AllowedPrimaryGroupIds`.

<!--- Results --->
%TestResult%
