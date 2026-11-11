Passwords expire after 60 days or less on every verified, managed domain. (DISA Microsoft Intune MDM Service Desktop STIG, V-267355, CAT II).

Intune sign-ins use Microsoft Entra ID passwords, so the password lifetime is set on the tenant's domains. The Intune STIG asks for 60 days, shorter than the 180 days of the newer Entra ID STIG.

This test runs [DISA.V-270239](https://maester.dev/docs/tests/DISA.V-270239) with a maximum of 60 days (`MaximumPasswordAgeDays`). Like that test, it conflicts with [CIS.M365.1.3.1](https://maester.dev/docs/tests/CIS.M365.1.3.1), which asks that passwords never expire.

#### Remediation action

1. In the [Microsoft 365 admin center](https://admin.microsoft.com), go to **Settings** > **Org settings** > **Security & privacy** > **[Password expiration policy](https://admin.microsoft.com/#/Settings/SecurityPrivacy/:/Settings/L1/PasswordPolicy)**.
2. Clear **Set passwords to never expire (recommended)**, set **Days before passwords expire** to **60** or less, and select **Save**.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop STIG: V-267355](https://cyber.trackr.live/stig/Intune_Service_Desktop/1/1/V-267355)
* [Set the password expiration policy for your organization](https://learn.microsoft.com/microsoft-365/admin/manage/set-password-expiration-policy)

<!--- Results --->
%TestResult%
