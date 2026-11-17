Emails detected as spam and phishing SHALL NOT be delivered to the user's inbox.

Rationale: Spam and phishing messages can reduce user productivity and include malicious links or attachments. Sending spam and phishing messages somewhere other than the inbox helps prevent users from interacting with them while preserving an option to review messages that were filtered incorrectly.

#### Remediation action

1. Sign in to **Microsoft 365 Defender**.
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > **Anti-spam**.
3. Identify the policies that apply to all recipients. ScubaGear evaluates the active Strict preset first, then Standard, enabled all-recipient custom policies, and finally the default policy. A compliant higher-priority policy shields lower-priority policies.
4. For the effective policy or policies, ensure **Spam**, **High confidence spam**, **Phishing**, and **High confidence phishing** actions do not deliver messages to the inbox. **Move to Junk**, **Quarantine**, **Redirect**, and **Delete** satisfy this requirement.
5. Save any changes.

#### Related links

* [Defender admin center - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [CISA Security Suite baseline - MS.SECURITYSUITE.6.1v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite61v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%
