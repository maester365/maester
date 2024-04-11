Legacy authentication SHALL be blocked.

Rationale: The security risk of allowing legacy authentication protocols is they do not support MFA. Blocking legacy protocols reduces the impact of user credential theft.[1](https://www.cisa.gov/resources-tools/services/secure-cloud-business-applications-scuba-project)

#### Test script
```
https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?$filter=(grantControls/builtInControls/any(c:c eq 'block')) and (conditions/clientAppTypes/any(c:c eq 'exchangeActiveSync')) and (conditions/clientAppTypes/any(c:c eq 'other')) and (conditions/users/includeUsers/any(c:c eq 'All'))&$count=true
.'@odata.count' = 1
```

#### Related links

- [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L47)
- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=identity%2FconditionalAccess%2Fpolicies%3F%24filter%3D(grantControls%2FbuiltInControls%2Fany(c%3Ac%2Beq%2B'block'))%2Band%2B(conditions%2FclientAppTypes%2Fany(c%3Ac%2Beq%2B'exchangeActiveSync'))%2Band%2B(conditions%2FclientAppTypes%2Fany(c%3Ac%2Beq%2B'other'))%2Band%2B(conditions%2Fusers%2FincludeUsers%2Fany(c%3Ac%2Beq%2B'All'))%26%24count%3Dtrue&method=GET&version=v1.0&GraphUrl=https://graph.microsoft.com)
- [List policies endpoint - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/conditionalaccessroot-list-policies?view=graph-rest-1.0)

<!--- Results --->
%TestResult%