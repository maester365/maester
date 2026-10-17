Priority account protection is turned on, priority accounts are defined, and alert policies notify people about malware and phishing sent to those accounts.

Executives, finance staff and IT administrators are targeted more often and the damage of a successful attack on them is higher. Priority account protection adds extra detection and reporting for them, and tags them in alerts and reports so that an incident response team notices them.

The test needs the protection to be on, at least one priority account, and an enabled alert for high severity inbound malware and one for high severity inbound phishing that apply to the Priority account tag and notify a user. Microsoft Defender for Office 365 Plan 2 licences are required.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Settings** > **Email & collaboration** > **Priority account protection** and turn on **Priority account protection**.
3. Go to **Settings** > **Email & collaboration** > **User tags**, open **Priority account** and add the accounts to tag.
4. Go to **Email & collaboration** > **Policies & rules** > **Alert policy** and create alerts for malware and phishing that use the **Priority account** user tag, a severity of **High**, the filter for inbound mail and a notification recipient.

#### Related links

* [Microsoft Defender portal - Priority account protection](https://security.microsoft.com/securitysettings/priorityAccountProtection)
* [Configure and manage priority accounts](https://learn.microsoft.com/defender-office-365/priority-accounts-turn-on-priority-account-protection)
* [Alert policies in the Microsoft Defender portal](https://learn.microsoft.com/defender-xdr/alert-policies)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.4.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
