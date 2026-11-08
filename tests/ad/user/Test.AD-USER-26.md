Only account SIDs, distinguished names or sAMAccountNames explicitly supplied in `AccountIds` are treated as decoys. Without configured IDs this check is not applicable; unknown IDs error. Attractive words in a name are never proof of a decoy.

#### Remediation action
1. Identify authorized decoy accounts and configure their IDs; review the accounts in [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Confirm alert coverage for attempted authentication separately; this test does not test monitoring.

<!--- Results --->
%TestResult%
