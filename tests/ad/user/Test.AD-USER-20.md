User names matching configurable `RegexPatterns` are an investigation inventory of possible service accounts, not evidence of their actual purpose. One consistent pattern set drives both count and details; malformed expressions produce errors. Service identities with SPNs are also covered by AD-SPN-06; AD-USER-14 was retired into that cross-feature check.

#### Control Type

**Detective**

#### Security Recommendation

Validate matched names with owners and prefer managed service accounts when practical. Naming patterns alone do not prove an account is used by a service.

#### How the Test Works

The test uses configured `RegexPatterns` consistently for both counts and account details; malformed patterns error. This is an investigation inventory, not a service-account classification.

#### Related Tests

- **AD-SPN-06 — User SPN total count should be investigated** — `Test-MtAdUserSpnTotalCount` — Inventories user-account SPNs (including former AD-USER-14).
- **AD-SPN-12 — No domain admin accounts should have SPNs configured** — `Test-MtAdUserSpnDomainAdminCount` — Checks SPNs on privileged users.

#### Remediation action
1. Confirm ownership, permissions and purpose of matches using [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Prefer managed service identities where feasible.

<!--- Results --->
%TestResult%
