Disabled ordinary users last modified over 180 days ago (configurable) require retention review. `Modified` is local `whenChanged`, **not** a disable date; other edits reset this estimate and it is not replicated. Protected/system accounts, RID 500–503, secondary krbtgt identities and Azure AD krbtgt accounts are excluded; this check does not delete RODC keys.

#### Remediation action
1. Verify the actual disable date and legal retention requirements with the account owner.
2. After approval, remove stale objects in [Active Directory Users and Computers](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).

<!--- Results --->
%TestResult%
