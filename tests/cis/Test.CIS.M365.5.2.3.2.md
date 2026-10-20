The custom banned password list in Microsoft Entra password protection is enabled and contains at least one word.

Password spray attacks try a small number of likely passwords against many accounts. Global banned passwords cover common choices, but words that are specific to your organisation, such as brand names, product names, locations and project names, are not covered unless you add them to the custom list.

The custom list is checked when a user changes or resets a password. Existing passwords are not affected until they change.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**Password protection**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection).
3. Set **Enforce custom list** to **Yes**.
4. Enter the words to block in **Custom banned password list**, one per line.
5. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Password protection](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)
* [Eliminate bad passwords using Microsoft Entra Password Protection](https://learn.microsoft.com/entra/identity/authentication/concept-password-ban-bad)
* [Configure custom banned passwords](https://learn.microsoft.com/entra/identity/authentication/tutorial-configure-custom-password-protection)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
