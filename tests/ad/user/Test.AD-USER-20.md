User names matching configurable `RegexPatterns` are an investigation inventory of possible service accounts, not evidence of their actual purpose. One consistent pattern set drives both count and details; malformed expressions produce errors. Service identities with SPNs are also covered by AD-SPN-06; AD-USER-14 was retired into that cross-feature check.

#### Remediation action
1. Confirm ownership, permissions and purpose of matches using [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Prefer managed service identities where feasible.

<!--- Results --->
%TestResult%
