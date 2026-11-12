The highest-priority anti-malware policy that applies to all users SHALL block click-to-run attachments, including at a minimum .exe, .cmd, and .vbe files.

Rationale: Malicious attachments often take the form of click-to-run files. Blocking a list of common executable files helps mitigate the risk of adversarial exploitation.

#### Remediation action

1. Sign in to **Microsoft 365 Defender**.
2. In the left-hand menu, go to **Email & Collaboration** > **Policies & Rules**.
3. Select **Threat Policies**.
4. From the **Templated policies** section, select **Preset Security Policies** and verify which enabled policy applies to all recipients.
5. In the effective policy, enable the common attachments filter and include at least `.exe`, `.cmd`, and `.vbe`. An all-recipient Strict preset takes precedence over Standard; otherwise check the highest-priority enabled custom rule that covers all accepted domains, or the Default policy when no such rule applies.

Note: If the toggle slider in step 5 is grayed out, click on **Manage protection settings** instead and configure the policy settings according to [Use the Microsoft 365 Defender portal to assign Standard and Strict preset security policies to users | Microsoft Learn](https://learn.microsoft.com/microsoft-365/security/office-365-security/preset-security-policies?view=o365-worldwide#use-the-microsoft-365-defender-portal-to-assign-standard-and-strict-preset-security-policies-to-users).

#### Related links

* [Defender admin center - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [CISA Security Suite baseline - MS.SECURITYSUITE.1.1v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite11v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%
