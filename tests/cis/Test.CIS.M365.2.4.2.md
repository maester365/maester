Every priority account is protected by the Strict preset security policy in both Exchange Online Protection and Defender for Office 365.

Executives, finance staff and administrators are the usual targets of spear phishing and whaling. Microsoft maintains the Standard and Strict preset security policies and updates them as threats change. Strict has the most aggressive settings for spam, phishing, malware, spoofing, impersonation, Safe Links and Safe Attachments, which suits the accounts that are most likely to be targeted and most valuable to compromise.

The test reads the Strict preset rules for Exchange Online Protection and for Defender for Office 365. Each rule must be on and must name its recipients with users, groups or domains. Every user tagged as a priority account must meet each recipient condition that is set, because different conditions apply together, and must not match an exception. A rule with no recipient conditions applies to everyone but fails, because CIS requires the rule to name the priority accounts. Preset security policies can't target user tags, so use a group that contains the priority accounts. Microsoft Defender for Office 365 licences are required.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > [**Preset security policies**](https://security.microsoft.com/presetSecurityPolicies).
3. Turn on **Strict protection** and select **Manage protection settings**.
4. On **Apply Exchange Online Protection**, select **Specific recipients** and add the users or groups that are your priority accounts.
5. On **Apply Defender for Office 365 protection**, select **Specific recipients** and add the same users or groups.
6. On **Add email addresses to flag when impersonated by attackers**, add the internal and external senders, including your priority accounts, that attackers may impersonate.
7. On **Add domains to flag when impersonated by attackers**, add the domains of key partners. Your accepted domains are protected automatically.
8. On **Review and confirm your changes**, select **Confirm**.

#### Related links

* [Microsoft Defender portal - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [Preset security policies in EOP and Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/preset-security-policies)
* [Security recommendations for priority accounts](https://learn.microsoft.com/defender-office-365/priority-accounts-security-recommendations)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.4.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
