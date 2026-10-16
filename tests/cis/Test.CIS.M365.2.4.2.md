The Strict preset security policy is turned on for both Exchange Online Protection and Defender for Office 365 and is assigned to recipients such as priority accounts.

Microsoft maintains the Standard and Strict preset security policies and updates them as threats change. Strict has the most aggressive settings for spam, phishing, malware, Safe Links and Safe Attachments, which suits the accounts that are most likely to be targeted and most valuable to compromise.

The test checks that the Strict rules are enabled and have at least one recipient condition: users, groups or domains. It does not check that the recipients are your priority accounts, so make sure the group you pick contains them. Microsoft Defender for Office 365 licences are required.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > [**Preset security policies**](https://security.microsoft.com/presetSecurityPolicies).
3. Under **Strict protection**, select **Manage protection settings**.
4. Apply the policy to **Specific recipients** and add your priority accounts or a group that contains them, for both Exchange Online Protection and Defender for Office 365.
5. Finish the wizard and turn the policy on.

#### Related links

* [Microsoft Defender portal - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [Preset security policies in EOP and Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/preset-security-policies)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.4.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
