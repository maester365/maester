Enabled users with a recorded logon older than the configurable 90-day threshold are dormant. Replicated `lastLogonTimestamp` can lag by approximately 14 days; missing timestamps need separate review.

#### Remediation action
1. Confirm actual use against domain-controller logon records before changing an account.
2. Disable unused identities through [Active Directory administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center) after owner approval.

<!--- Results --->
%TestResult%
