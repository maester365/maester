An enabled Conditional Access policy requires multifactor authentication for all users, in all cloud apps.

Passwords are the most common way into Microsoft 365 accounts: they are phished, reused, guessed and sprayed. Requiring a second factor for every user at sign-in blocks most of these attacks even when the password is known.

The policy must target all users and all resources, require MFA or an authentication strength, and be enabled. Policies that apply only at a certain risk level, or that are in report-only mode, do not satisfy the test. Excluding emergency access accounts is expected.

User and group exclusions are not evaluated by this test. Application exclusions are evaluated; Microsoft Rights Management Services (`00000012-0000-0000-c000-000000000000`) is the only allowed exclusion. The benchmark recommends this exception so external users can open documents protected by sensitivity labels. Any other excluded application causes the policy to fail, and the result lists excluded applications.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**. If external users need to open documents protected by sensitivity labels, exclude Microsoft Rights Management Services (`00000012-0000-0000-c000-000000000000`); do not add other application exclusions.
5. Under **Grant**, select **Grant access** and **Require multifactor authentication** (or **Require authentication strength**).
6. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Require multifactor authentication for all users with Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa)
* [Plan a Conditional Access deployment](https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
