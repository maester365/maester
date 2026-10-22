At least one IP-based named location with address ranges exists and is marked as trusted.

Named locations give Conditional Access a way to tell your offices and known egress addresses from the rest of the internet. Marked as trusted, they feed Microsoft Entra ID Protection and let policies relax or tighten requirements by network.

The test passes when at least one IP named location has ranges and is trusted. Country-based locations are not counted. Only mark a network as trusted when it is under your control.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Named locations**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/NamedLocations).
3. Select **IP ranges location**.
4. Enter a name and add the public IP ranges of your offices or egress points.
5. Select **Mark as trusted location** and then **Create**.

#### Related links

* [Microsoft Entra admin center - Named locations](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/NamedLocations)
* [Conditional Access: network assignments](https://learn.microsoft.com/entra/identity/conditional-access/concept-assignment-network)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.14](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
