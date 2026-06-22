When the Global Secure Access **Internet Access** traffic forwarding profile is enabled, internet traffic is acquired and tunnelled through the service. If no filtering profile enforces a policy, that traffic is tunnelled but **unprotected** - you acquire internet egress and get only logging, no filtering.

At least one Global Secure Access filtering / security profile should have an active policy linked (web content filtering, threat intelligence, TLS inspection, or cloud firewall) - either the baseline profile or a Conditional Access-linked profile.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Global Secure Access Administrator**.
2. Browse to **Global Secure Access** > **Secure** > **Security profiles** (and **Web content filtering** / **Threat intelligence policies**).
3. Link at least one enabled filtering policy to the baseline security profile, or link a security profile via a Conditional Access policy.

#### Related links

* [Global Secure Access security profiles](https://learn.microsoft.com/entra/global-secure-access/concept-security-profiles)
* [How to configure web content filtering](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-web-content-filtering)

<!--- Results --->
%TestResult%
