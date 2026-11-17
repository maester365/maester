Emails identified as containing malware SHALL be quarantined or dropped.

Rationale: Email can be used as a mechanism for delivering malware. Preventing emails with known malware from reaching user mailboxes helps ensure users cannot interact with those emails.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > **Safe attachments**.
3. Ensure that either the Strict or Standard preset security policy covers all users. If neither preset policy covers all users, create or update a Safe Attachments policy and its rule to cover every accepted domain.
4. Set the policy's unknown malware response to **Block** or **Dynamic Delivery**.

#### Related links

* [CISA Security Suite baseline - MS.SECURITYSUITE.1.3v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite13v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)
* [Microsoft Learn - Safe Attachments policies](https://learn.microsoft.com/defender-office-365/safe-attachments-policies-configure)
* [Microsoft Learn - Order and precedence of email protection](https://learn.microsoft.com/defender-office-365/how-policies-and-protections-are-combined)

<!--- Results --->
%TestResult%
