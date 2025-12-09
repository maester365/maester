Checks if any conditional access policy explicitly includes Azure DevOps

## Description
If your organization has Conditional Access policies targeting the Windows Azure Service Management API (App ID: 797f4846-ba00-4fd7-ba43-dac1f8f63013), those policies will no longer apply to Azure DevOps sign-ins. This may result in unprotected access unless these policies are updated to include Azure DevOps (App ID: 499b84ac-1321-427f-aa17-267ca6975798).

Access controls such as MFA or compliant device requirements may not be enforced unless policies are updated.
If you already have a policy that targets all users and all cloud apps and does not explicitly exclude Azure DevOps, no action is required—Azure DevOps sign-ins will continue to be protected.
This change does not introduce any new user-facing experience or UI changes.
Sign-in activity can be monitored using Microsoft Entra ID sign-in logs.
Licensing requirement: Microsoft Entra ID P1 or P2 is required. There are no functional differences by license type. This is a feature change, not a new feature, so trial or preview options are not applicable.
Unlicensed users may also be impacted.
Existing Conditional Access policies will be affected, specifically those targeting the Windows Azure Service Management API.
A small subset of tenants may see the app name as "Microsoft Visual Studio Team Services" instead of "Azure DevOps"—the App ID remains the same.

## Remediate
To ensure continued protection of Azure DevOps sign-ins, administrators should:

Update policies to include Azure DevOps:
1. Review existing Conditional Access policies - Identify any policies that target the Windows Azure Service Management API.
2. Go to the Entra admin center.
3. Navigate to Entra ID > Conditional Access > Policies.
4. Select the relevant policy.
5. Under Target resources, choose Select resources and add Azure DevOps (App ID: 499b84ac-1321-427f-aa17-267ca6975798).
    - If Azure DevOps is missing from available resources:
```
Connect-MgGraph -Scopes "Directory.ReadWrite.All", "Application.ReadWrite.All"
$params = @{
	appId = "499b84ac-1321-427f-aa17-267ca6975798"
}
Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" -Method POST -Body $params
```
6. Save the policy.

## Learn more
- [Removing Azure Resource Manager reliance on Azure DevOps sign-ins | Azure DevOps Blog](https://devblogs.microsoft.com/devops/removing-azure-resource-manager-reliance-on-azure-devops-sign-ins/)
- [What is Conditional Access? | Conditional Access | Microsoft Entra ID | Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview)

<!--- Results --->
%TestResult%