Emergency access (break-glass) accounts must stay usable when everything else fails, so Conditional Access policies should not block them.

Maester finds up to five emergency access accounts (the users or group most often excluded from Conditional Access policies) and evaluates a sign-in for each with the Conditional Access What If API. One result is created per account (MT.1034.&lt;n&gt;). The check fails when any policy applies to the account.

Learn more:
- [Manage emergency access accounts in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)
- [Conditional Access What If tool](https://learn.microsoft.com/entra/identity/conditional-access/what-if-tool)

#### Remediation action

Exclude your emergency access accounts from the Conditional Access policies that apply to them.

<!--- Results --->
%TestResult%
