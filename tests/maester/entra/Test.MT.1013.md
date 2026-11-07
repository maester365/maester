Checks if the tenant has at least one Conditional Access policy requiring password change for high user risk.

This check is skipped when [MT.1253](https://maester.dev/docs/tests/MT.1253) is met: an enabled policy requires **Require risk remediation** for high user risk. Risk remediation replaces **Require password change** and also remediates users who sign in without a password, so a tenant that uses it does not need a password change policy.

See [User risk-based password change - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk-user)
<!--- Results --->
%TestResult%
