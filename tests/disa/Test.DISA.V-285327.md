An Intune Multi Admin Approval policy requires a second administrator to approve device wipes. (DISA Microsoft Intune MDM Service Desktop and Mobile STIG, V-285327, CAT I).

One compromised or careless Intune administrator can wipe every managed device in a few clicks. Multi Admin Approval makes a second administrator approve the wipe before it runs, which is why DISA rates this rule CAT I.

This test runs [MT.1096](https://maester.dev/docs/tests/MT.1096) with `RequiredPolicyType`, so it passes only when an approval policy covers device wipes (a **Device wipe** or **Device actions** policy). The STIG also asks you to confirm that the approver group is the right one and that the policy itself is approved; check that by hand.

#### Remediation action

1. Create a Microsoft Entra security group for the administrators who approve device wipes.
2. In the [Microsoft Intune admin center](https://intune.microsoft.com), go to **Tenant administration** > **[Multi Admin Approval](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/TenantAdminMenu/~/multiAdminApproval)** > **Access policies** and select **Create**.
3. Set **Policy type** to **Device wipe** (or **Device actions**), select the approver group, and save.
4. Have another administrator approve the new policy.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop and Mobile STIG: V-285327](https://cyber.trackr.live/stig/Intune_MDM_Service_Desktop_&_Mobile/1/2/V-285327)
* [Use Multi Admin Approval in Intune](https://learn.microsoft.com/intune/intune-service/fundamentals/multi-admin-approval)

<!--- Results --->
%TestResult%
