1.3.1 (L1) Ensure the 'Password expiration policy' is set to 'Set passwords to never expire (recommended)'

Microsoft cloud-only accounts have a pre-defined password policy that cannot be changed. The only items that can change are the number of days until a password expires and whether or not passwords expire at all.

#### Rationale

Organizations such as NIST and Microsoft recommend against arbitrarily requiring users to change their passwords after a set period, unless there is evidence of compromise or the user has forgotten the password. This guidance applies even to single-factor (password-only) scenarios, as forced, periodic changes often lead to weaker passwords and reduced security. Additionally, this Benchmark advises implementing multi-factor authentication (MFA) for all accounts, which further diminishes the value of password expiration policies. Long-lived passwords can be further strengthened by enabling additional password protection features in Entra ID.

#### Impact

When setting passwords not to expire it is important to have other controls in place to supplement this setting. See below for related recommendations and user guidance.

* Ban common passwords.
* Educate users to not reuse organization passwords anywhere else.
* Enforce Multi-Factor Authentication registration for all users.

#### Remediation action

To set Office 365 passwords are set to never expire:

1. Navigate to [Microsoft 365 admin center](https://admin.microsoft.com).
2. Click to expand **Settings** select **Org Settings**.
3. Click on **Security & privacy**.
4. Check the **Set passwords to never expire (recommended)** box.
5. Click **Save**.

##### PowerShell

1. Connect to the Microsoft Graph service using `Connect-MgGraph -Scopes "Domain.ReadWrite.All"`.
2. Run the following Microsoft Graph PowerShell command:

```powershell
Update-MgDomain -DomainId <Domain> -PasswordValidityPeriodInDays 2147483647
```

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [NIST Special Publication 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html)
* [CIS Password Policy Guide](https://www.cisecurity.org/insights/white-papers/cis-password-policy-guide)
* [Password policy recommendations for Microsoft 365 passwords](https://learn.microsoft.com/microsoft-365/admin/misc/password-policy-recommendations?view=o365-worldwide)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - Page 47](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
