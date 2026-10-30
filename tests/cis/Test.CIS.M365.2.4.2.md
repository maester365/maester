The Strict preset security policy applies its strongest protections to the recipients selected for Exchange Online Protection and Defender for Office 365.

Microsoft maintains the Standard and Strict preset security policies and updates them as threats change. Strict has the most aggressive settings for spam, phishing, malware, Safe Links and Safe Attachments, which suits the accounts that are most likely to be targeted and most valuable to compromise.

When enabled, a rule with no recipient conditions applies to everyone, including priority accounts. This test follows the CIS PowerShell audit procedure literally: it requires at least one explicit recipient condition on each enabled rule to pass. It does not verify that the selected recipients actually include priority accounts. To meet the audit criterion while targeting those accounts, add a group containing priority accounts to the rule's `SentToMemberOf` condition. Microsoft Defender for Office 365 licences are required.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > [**Preset security policies**](https://security.microsoft.com/presetSecurityPolicies).
3. Under **Strict protection**, select **Manage protection settings**.
4. Apply the policy to **Specific recipients** and add a group containing priority accounts so each rule has a `SentToMemberOf` condition.
5. Finish the wizard and turn the policy on.

#### Related links

* [Microsoft Defender portal - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [Preset security policies in EOP and Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/preset-security-policies)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.4.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
