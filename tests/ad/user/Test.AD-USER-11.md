Accounts with `AdminCount=1` require human review; this flag can persist after privileged group removal and is not proof of current administrator rights.

#### Remediation action
1. Review group membership and inherited permissions in [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Remove unnecessary privileges; clear stale protection only after validating the account is no longer protected.

<!--- Results --->
%TestResult%
