The **baseline** security profile (priority 65000) applies to all Internet Access traffic with no Conditional Access required. Linking an enabled **threat-intelligence** policy to the baseline provides an always-on malware and phishing floor.

The baseline is the only place that protects **non-client / remote-network** traffic, the Conditional Access **token-propagation gap**, and users **not matched** by any user-aware (CA-linked) profile. Microsoft recommends linking the threat-intelligence policy to the baseline because it applies to all users' traffic.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Global Secure Access Administrator**.
2. Browse to **Global Secure Access** > **Secure** > **Threat intelligence policies** and create or enable a policy.
3. Link the threat-intelligence policy to the **baseline** security profile.

#### Related links

* [Global Secure Access threat intelligence](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-threat-intelligence)
* [Global Secure Access security profiles](https://learn.microsoft.com/entra/global-secure-access/concept-security-profiles)

<!--- Results --->
%TestResult%
