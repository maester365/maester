Priority account protection is turned on, priority accounts are defined, and alert policies notify people about malware and phishing sent to those accounts.

Executives, finance staff and IT administrators are targeted more often and the damage of a successful attack on them is higher. Priority account protection adds extra detection and reporting for them, and tags them in alerts and reports so that an incident response team notices them.

The test needs the protection to be on, at least one priority account, and an enabled alert for high severity inbound malware and one for high severity inbound phishing that apply to the Priority account tag and notify a user. Microsoft Defender for Office 365 Plan 2 licences are required.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **System** > **Settings** > **Email & collaboration** > [**Priority account protection**](https://security.microsoft.com/securitysettings/priorityAccountProtection) and turn on **Priority account protection**.
3. Select **User tags**, select the **Priority account** tag and select **Edit**. Add the users or groups that are your priority accounts (groups are recommended), then select **Next** and **Submit**. Repeat for any other tags you use, such as Finance or HR.
4. Go to **Email & collaboration** > **Policies & rules** > [**Alert policy**](https://security.microsoft.com/alertpoliciesv2) and select **New alert policy**.
5. Enter a name and description, set **Severity** to **High** and **Category** to **Threat management**.
6. Set **Activity is** to **Detected malware in an email message** and the mail direction to **Inbound**.
7. Select **Add condition** > **User: recipient tags are** and select **Priority account**.
8. Select **Every time an activity matches the rule**, select **Next** and add the recipients who should be notified.
9. Select **Yes, turn it on right away** and **Submit**.
10. Repeat steps 4 to 9 with **Activity is** set to **Phishing email detected at time of delivery**.

#### Related links

* [Microsoft Defender portal - Priority account protection](https://security.microsoft.com/securitysettings/priorityAccountProtection)
* [Configure and manage priority accounts](https://learn.microsoft.com/defender-office-365/priority-accounts-turn-on-priority-account-protection)
* [Alert policies in the Microsoft Defender portal](https://learn.microsoft.com/defender-xdr/alert-policies)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.4.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
