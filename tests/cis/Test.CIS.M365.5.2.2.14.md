At least one IP-based named location with a public address range exists and is marked as trusted.

Named locations give Conditional Access a way to tell your offices and known egress addresses from the rest of the internet. Marked as trusted, they feed Microsoft Entra ID Protection and let policies relax or tighten requirements by network.

The test passes when at least one IP named location has a public range and is trusted. A range in private or other non-routable address space, such as 10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16, doesn't count: Microsoft Entra ID evaluates the public address that a network uses to reach the internet, never the address of a device on the intranet, so these ranges never match a sign-in. Country-based locations are not counted. Only mark a network as trusted when it is under your control.

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
