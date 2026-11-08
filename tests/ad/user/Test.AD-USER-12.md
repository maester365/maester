Ordinary users should use approved primary group RIDs (default 513, Domain Users). Protected identities and built-in RID 500–503 accounts are exempt. Hidden primary group membership can complicate reviews.

#### Remediation action
1. Validate required group membership, then restore an approved primary group through [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Add documented legitimate RID exceptions to `AllowedPrimaryGroupIds`.

<!--- Results --->
%TestResult%
