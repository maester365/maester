Manages controls who can invite guests to your directory to collaborate on resources secured by your Entra ID (Azure AD), such as SharePoint sites or Azure resources.

CISA SCuBA 2.18: Only users with the Guest Inviter role SHOULD be able to invite guest users

#### Test script
```
https://graph.microsoft.com/beta/policies/authorizationPolicy
.allowInvitesFrom -in @('adminsAndGuestInviters','none')
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AllowlistPolicyBlade)

<!--- Results --->
%TestResult%
