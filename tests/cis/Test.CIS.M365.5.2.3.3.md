Microsoft Entra password protection is enabled for on-premises Active Directory and runs in enforced mode.

Hybrid environments allow password changes against domain controllers. Without the on-premises integration, those changes bypass the banned password lists, so users can set passwords that the cloud would reject. In audit mode, banned passwords are only logged and are still accepted.

The setting does not take effect until the password protection proxy service and the domain controller agent are installed. If your tenant has no on-premises Active Directory, this recommendation does not apply.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**Password protection**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection).
3. Set **Enable password protection on Windows Server Active Directory** to **Yes**.
4. Set **Mode** to **Enforced**. Use **Audit** first if you want to measure impact before enforcing.
5. Select **Save**.
6. Install the Microsoft Entra password protection proxy and domain controller agent on-premises if they are not deployed yet.

#### Related links

* [Microsoft Entra admin center - Password protection](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)
* [Plan and deploy on-premises Microsoft Entra Password Protection](https://learn.microsoft.com/entra/identity/authentication/howto-password-ban-bad-on-premises-deploy)
* [Enforce on-premises Microsoft Entra Password Protection](https://learn.microsoft.com/entra/identity/authentication/concept-password-ban-bad-on-premises)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
