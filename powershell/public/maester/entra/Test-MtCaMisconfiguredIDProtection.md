Checks if both user risk and sign-in risk are configured in one conditional access policy.

Combining sign in risk and user risk in one policy will only block access if both types of risk are flagged for a given sign in.

This means if only one type of risk is present (eg Sign-in risk = High, User risk = None), the sign-in will be allowed to proceed. This could create a security gap since risky activities might slip through.


See [Sign-in risk-based multifactor authentication - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk)
<!--- Results --->
%TestResult%