An enabled Conditional Access policy blocks sign-ins from every location except the trusted ones.

Most organisations know where their staff sign in from. A policy that blocks all locations except the trusted ones, or the countries you operate in, stops a large share of credential attacks that come from elsewhere without any extra step for users.

The policy must apply to all users and all cloud apps, include locations, exclude only trusted named locations, block access and be enabled. Plan for travelling users, for example with a temporary exclusion group, and remember that attackers can use VPNs in allowed countries, so this does not replace MFA.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Make sure your trusted locations exist in [Named locations](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/NamedLocations) and are marked as trusted.
3. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
4. Under **Users**, include **All users**. Exclude your emergency access accounts.
5. Under **Target resources**, select **All resources (formerly All cloud apps)**.
6. Under **Conditions** > **Locations**, set **Configure** to **Yes**, include **Any network or location** and exclude your trusted locations (or **All trusted networks and locations**).
7. Under **Grant**, select **Block access**.
8. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Block access by location with Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/policy-block-by-location)
* [Conditional Access: network assignments](https://learn.microsoft.com/entra/identity/conditional-access/concept-assignment-network)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.15](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
