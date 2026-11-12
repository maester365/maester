No privileged Microsoft Entra role has an active assignment that never ends. (DISA Microsoft Entra ID STIG, V-270335, CAT II).

A permanent active assignment keeps admin rights on an account around the clock, so a stolen session or password gives them straight away. With Privileged Identity Management, users hold the role only when they activate it, for a limited time.

DISA's check looks at the active assignments of each privileged role and is a finding when one ends **Permanent**. This test runs [CISA.MS.AAD.7.4](https://maester.dev/docs/tests/CISA.MS.AAD.7.4), which checks the roles that CISA counts as highly privileged. Review the other privileged roles in your tenant by hand.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **ID Governance** > **Privileged Identity Management** > **[Microsoft Entra roles](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles)** > **Assignments**.
2. On the **Active assignments** tab, find the assignments whose end time is **Permanent**.
3. Change each one to an eligible assignment, leaving permanent active assignments only on your emergency access accounts.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270335](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270335)
* [Start using Privileged Identity Management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-getting-started)

<!--- Results --->
%TestResult%
