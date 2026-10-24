Subscriptions should be blocked from leaving the tenant.

Allowing subscriptions to leave the tenant without restriction can let a privileged user transfer a subscription and its resources to an external tenant. The tenant subscription policy can require explicit authorization before a subscription is moved. The Microsoft default is that when there is no policy, the block is enabled by default.

#### Remediation action

1. Sign in to the [Azure portal](https://portal.azure.com) as a user with the **Subscription Policy Contributor** or **Owner** role at the tenant scope. A directly assigned Global Admin can do this.
2. Open a PowerShell Cloud Shell session and enable the policy:

```powershell
$token = (Get-AzAccessToken).Token
$body = @{ blockSubscriptionsLeavingTenant = $true } | ConvertTo-Json
Invoke-RestMethod -Method PUT -Uri "https://management.azure.com/providers/Microsoft.Subscription/policies/default?api-version=2021-10-01" -Authentication Bearer -Token $token -Body $body
```

3. Confirm `properties.blockSubscriptionsLeavingTenant` is `true` in the policy response.

#### Related links

- [Manage Azure subscription policies - Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/manage-azure-subscription-policy)
- [Azure portal](https://portal.azure.com)

<!--- Results --->
%TestResult%