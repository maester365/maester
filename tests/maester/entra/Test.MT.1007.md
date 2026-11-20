This test checks if the tenant has at least one Conditional Access policy requiring MFA for all users.

A policy that accepts a custom control instead of MFA doesn't count: custom controls don't satisfy the multifactor authentication requirement, and Microsoft deprecated them in favor of external MFA. The test result lists these policies. A policy that requires MFA and a custom control (AND) still counts.

See [Require MFA for all users - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa) and [Migrate from custom controls to external multifactor authentication - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/how-to-migrate-custom-controls-external-mfa)
<!--- Results --->
%TestResult%