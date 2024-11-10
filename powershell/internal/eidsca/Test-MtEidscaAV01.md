Whether the Voice call is enabled in the tenant.

Choose authentication methods with number matching (Authenticator) 

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')
.state -eq 'disabled'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)



<!--- Results --->
%TestResult%
