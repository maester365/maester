An enabled Conditional Access policy requires MFA every time a user enrols a device in Microsoft Intune.

Enrolling a device gives it a managed identity that other Conditional Access policies trust. If an attacker enrols a device with a stolen session, that device then satisfies the managed device requirements. Asking for a fresh MFA on every enrolment keeps the enrolment step tied to the real user.

The policy targets the Microsoft Intune Enrollment cloud app, which appears in the app picker once Intune is licensed.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **Select resources** and add **Microsoft Intune Enrollment**.
5. Under **Grant**, select **Grant access** and **Require multifactor authentication**.
6. Under **Session**, select **Sign-in frequency** and set it to **Every time**.
7. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Conditional Access session controls: sign-in frequency](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-session#sign-in-frequency)
* [Require MFA for device enrollment](https://learn.microsoft.com/intune/intune-service/enrollment/multi-factor-authentication)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.11](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
