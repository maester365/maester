Multi-factor authentication is used to authenticate human users to their organisation's online services that process, store or communicate their organisation's sensitive data (ISM-1504, Essential Eight Maturity Level One).

A password alone is defeated by phishing, password spray and credential stuffing. Requiring a second factor for every user on every resource is the first Essential Eight requirement for multi-factor authentication, and the baseline the phishing-resistant requirement of Maturity Level Two builds on.

ASD defines which factors count, not how the policy is built, so this test runs the same check as [CIS.M365.5.2.2.2](https://maester.dev/docs/tests/CIS.M365.5.2.2.2). It looks for an enabled Conditional Access policy that targets all users and all resources and requires multi-factor authentication or an authentication strength. Policies that apply only at a certain risk level, exclude applications or are narrowed by a condition such as a platform or location do not count. The shared check does not assess user or group exclusions, so review those separately. Excluding emergency access accounts is expected.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Grant**, select **Grant access** and **Require multifactor authentication** (or **Require authentication strength**).
6. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Essential Eight assessment process guide](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-assessment-process-guide)
* [Require multifactor authentication for all users with Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa)

<!--- Results --->
%TestResult%
