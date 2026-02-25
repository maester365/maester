5.2.3.5 (L1) Ensure weak authentication methods are disabled

**Rationale:**
The SMS and Voice call methods are vulnerable to SIM swapping which could allow an attacker to gain access to your Microsoft 365 account.

#### Remediation action:

1. Navigate to Microsoft Entra ID admin center [https://entra.microsoft.com](https://entra.microsoft.com).
2. Under **Entra ID** select **Authentication methods**
3. Under **Manage** select **Policies**
4. Ensure that **SMS**, **Voice call** and **Email OTP** are disabled

#### Related links

* [Microsoft 365 Entra admin Center | Authentication methods | Policies](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 259](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%