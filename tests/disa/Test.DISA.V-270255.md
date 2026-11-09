Every Microsoft Entra role with an active or eligible assignment sends its Privileged Identity Management activation alert to the system administrators and the information system security officer (DISA Microsoft Entra ID STIG, V-270255, CAT II).

When an eligible user activates a role, Privileged Identity Management can email an alert. Sending it to the people who watch the system (DISA names the SA and the ISSO) means an unexpected activation, such as one made with stolen credentials, is seen while the elevation is still active. DISA asks for this on every role that has an assignment, not only the most privileged ones.

The check lists the roles that have an active or eligible assignment and reads the **Additional recipients** of each role's **Role activation alert**. A role fails when that list is empty. Set `RequiredRecipient` to the SA and ISSO addresses to require those exact recipients. [CISA.MS.AAD.7.8](https://maester.dev/docs/tests/CISA.MS.AAD.7.8) and [CISA.MS.AAD.7.9](https://maester.dev/docs/tests/CISA.MS.AAD.7.9) read the same alert for the highly privileged roles only.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **ID Governance** > **Privileged Identity Management** > **[Microsoft Entra roles](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles)** > **Settings**.
2. For each role this test lists, select the role and **Edit**.
3. On the **Notification** tab, under **Send notifications when eligible members activate this role**, add the SA and ISSO addresses as **Additional recipients** of the **Role activation alert**.
4. Select **Update**.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270255](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270255)
* [Configure Microsoft Entra role settings in Privileged Identity Management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-change-default-settings)

<!--- Results --->
%TestResult%
