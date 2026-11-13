URL comparison with a block-list SHOULD be enabled for URLs in emails, Teams messages, and Office documents.

Rationale: Users may be directed to malicious websites via links in email. Blocking access to known, malicious URLs can prevent users from accessing known malicious websites.

#### Remediation action:

1. Sign in to **Microsoft 365 Defender**.
2. In the left-hand menu, go to **Email & Collaboration** > **Policies & Rules**.
3. Select **Threat Policies**.
4. From the **Templated policies** section, select **Preset Security Policies**.
5. Under either **Standard protection** or **Strict protection**, select **Manage protection settings**.
6. Select **Next** until you reach the **Apply Defender for Office 365 protection** page.
7. Ensure Safe Links protection is enabled for email, Teams messages, and Office documents.
8. On the **Apply Defender for Office 365 protection** page, select **All recipients**.
9. (Optional) Under **Exclude these recipients**, add **Users** and **Groups** to be exempted from the preset policies.
10. Select **Next** on each page until the **Review and confirm your changes** page.
11. On the **Review and confirm your changes** page, select **Confirm**.

If neither preset policy has an enabled rule covering all recipients, configure the highest-priority enabled Safe Links rule that applies to all recipients. Ensure it also enables protection for internal senders.

#### Related links

* [Defender admin center - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [CISA Security Suite baseline - MS.SECURITYSUITE.7.1v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite71v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%