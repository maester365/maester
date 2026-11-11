Domain impersonation protection SHOULD be added for key suppliers and partners.

Protection should cover the partner domains configured for this test. ScubaGear also requires `PartnerDomains` to be configured; an empty list is not treated as evidence of compliance.

#### Remediation action

1. Configure the `PartnerDomains` parameter for this test with the email domains of key suppliers and partners.
2. Sign in to the [Microsoft Defender anti-phishing policies page](https://security.microsoft.com/antiphishing).
3. Edit an enabled anti-phishing policy that applies to all recipients. Add every configured domain under **Domains to protect** and choose one of the baseline actions: redirect, move the message to Junk Email, quarantine, or delete.
4. Save the policy.
5. If using Standard or Strict preset protection, select **All recipients** without exclusions on both **Apply Exchange Online Protection** and **Apply Defender for Office 365 protection**. EOP recipient coverage alone does not establish impersonation protection.

#### Related links

* [Anti-phishing policies in Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/anti-phishing-policies-about)
* [CISA Security Suite baseline - MS.SECURITYSUITE.2.3v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite23v1)

<!--- Results --->
%TestResult%
