Specifies the duration the request is active before it automatically expires if no decision is applied



#### Test script
```
https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy
.requestDurationInDays -le '30'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/adminConsentRequestPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [adminConsentRequestPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/adminconsentrequestpolicy)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/AdminConsentSettings)

<!--- Results --->
%TestResult%
