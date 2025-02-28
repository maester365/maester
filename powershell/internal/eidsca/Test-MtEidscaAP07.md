Represents role templateId for the role that should be granted to guest user.

CISA SCuBA 2.18: Guest users SHOULD have limited access to Entra ID (Azure AD) directory objects.

#### Test script
```
https://graph.microsoft.com/beta/policies/authorizationPolicy
.guestUserRoleId -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AllowlistPolicyBlade)

<!--- Results --->
%TestResult%
