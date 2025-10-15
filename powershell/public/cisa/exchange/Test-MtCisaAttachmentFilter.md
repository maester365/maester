Emails SHALL be filtered by attachment file types.

Rationale: Malicious attachments often take the form of click-to-run files. Sharing high risk file types, when necessary, is better left to a means other than email; the dangers of allowing them to be sent over email outweigh any potential benefits. Filtering email attachments based on file types can prevent spread of malware distributed via click-to-run email attachments.

#### Remediation action:

1. Sign in to **Microsoft 365 Defender**.
2. In the left-hand menu, go to **Email & Collaboration** > **Policies & Rules**.
3. Select **Threat Policies**.
4. From the **Templated policies** section, select **Preset Security Policies**.
5. Under **Standard protection**, slide the toggle switch to the right so the text next to the toggle reads **Standard protection is on**.
6. Under **Strict protection**, slide the toggle switch to the right so the text next to the toggle reads **Strict protection is on**.

Note: If the toggle slider in step 5 is grayed out, click on **Manage protection settings** instead and configure the policy settings according to [Use the Microsoft 365 Defender portal to assign Standard and Strict preset security policies to users | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/preset-security-policies?view=o365-worldwide#use-the-microsoft-365-defender-portal-to-assign-standard-and-strict-preset-security-policies-to-users).

#### Related links

* [Defender admin center - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [Defender admin center - Order and precedence of email protection](https://learn.microsoft.com/en-us/defender-office-365/how-policies-and-protections-are-combined)
* [CISA 9 Attachment File Type - MS.EXO.9.1v2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo91v2)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L487)
* [Microsoft Learn - Common attachments filter in anti-malware policies](https://learn.microsoft.com/en-us/defender-office-365/anti-malware-protection-about#common-attachments-filter-in-anti-malware-policies)

<!--- Results --->
%TestResult%