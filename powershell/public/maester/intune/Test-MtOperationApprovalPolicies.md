Ensure at least one Intune Multi Admin Approval Policy is configured. Microsoft Intune Multi Admin Approval helps to limit the impact of compromised administrators by requiring approval for sensitive activities.

#### Remediation action:

To create a multi admin approval policy:
1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Click **Tenant Administration** and select **Multi Admin Approval** or use the [Microsoft Intune Portal - Multi Admin Approval direct link](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/TenantAdminMenu/~/multiAdminApproval).
3. Select **Access policies** and create a new access policy, e.g. for Scripts
4. Let another Intune Administrator approve your request to create the access policy
5. Re-visit the access policies section and complete the policy creation.

Additional information:

* [Use Access policies to require Multi Admin Approval](https://learn.microsoft.com/intune/intune-service/fundamentals/multi-admin-approval)

<!--- Results --->
%TestResult%