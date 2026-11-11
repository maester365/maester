Passwords expire after 180 days or less on every verified, managed domain (DISA Microsoft Entra ID STIG, V-270239, CAT II).

DISA requires a maximum password lifetime, so a password that leaked without anyone noticing stops working after a known time. In Microsoft 365 the password expiration policy is set per domain, and it applies to the verified domains that are managed by Microsoft Entra ID (federated domains follow the identity provider's policy).

The check fails when a verified, managed domain never expires passwords or sets a lifetime longer than 180 days (`MaximumPasswordAgeDays`). A domain that stores no period is reported for review, because the API does not say whether the default of 90 days the STIG mentions applies or, as in newer tenants, passwords never expire.

**This conflicts with CIS.** [CIS.M365.1.3.1](https://maester.dev/docs/tests/CIS.M365.1.3.1) reads the same setting and asks that passwords never expire, as NIST SP 800-63B recommends. A tenant can pass only one of the two tests; run the one your organization is assessed against.

#### Remediation action

1. In the [Microsoft 365 admin center](https://admin.microsoft.com), go to **Settings** > **Org settings** > **Security & privacy** > **[Password expiration policy](https://admin.microsoft.com/#/Settings/SecurityPrivacy/:/Settings/L1/PasswordPolicy)**.
2. Clear **Set passwords to never expire (recommended)**.
3. Set **Days before passwords expire** to **180** or less, and select **Save**.

The admin center sets the period on every domain. To set one domain, use `Update-MgDomain -DomainId <domain> -PasswordValidityPeriodInDays 180`.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270239](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270239)
* [Set the password expiration policy for your organization](https://learn.microsoft.com/microsoft-365/admin/manage/set-password-expiration-policy)

<!--- Results --->
%TestResult%
