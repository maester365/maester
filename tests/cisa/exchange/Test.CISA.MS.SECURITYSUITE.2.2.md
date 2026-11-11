Domain impersonation protection SHOULD be enabled for domains owned by the agency.

Configuring protection for owned domains reduces the risk that users will be deceived by a look-alike domain. The enabled anti-phishing policy must cover all recipients and use an action that does not leave the message unprotected.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com/antiphishing).
2. Edit the default anti-phishing policy or an enabled policy that applies to all recipients.
3. Under **Phishing threshold and protection**, enable **Domains I own** and choose one of the baseline actions: redirect, move the message to Junk Email, quarantine, or delete.
4. Save the policy and verify its recipient scope includes all tenant users.
5. If using Standard or Strict preset protection, select **All recipients** without exclusions on both **Apply Exchange Online Protection** and **Apply Defender for Office 365 protection**. EOP recipient coverage alone does not establish impersonation protection.

#### Related links

* [Anti-phishing policies in Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/anti-phishing-policies-about)
* [CISA Security Suite baseline - MS.SECURITYSUITE.2.2v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite22v1)

<!--- Results --->
%TestResult%
