DKIM SHOULD be enabled for all domains.

Rationale: An adversary may modify the `FROM` field of an email such that it appears to be a legitimate email sent by an agency, facilitating phishing attacks. Enabling DKIM is another means for recipients to detect spoofed emails and verify the integrity of email content.

#### Remediation action:

To enable DKIM, follow the instructions listed on [Steps to Create, enable and disable DKIM from Microsoft 365 Defender portal | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/email-authentication-dkim-configure?view=o365-worldwide#steps-to-create-enable-and-disable-dkim-from-microsoft-365-defender-portal).

#### Related links

* [Defender admin center - Email authentication settings](https://security.microsoft.com/authentication?viewid=DKIM)
* [CISA 3 Sender Policy Framework - MS.EXO.3.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo31v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L107)

<!--- Results --->
%TestResult%