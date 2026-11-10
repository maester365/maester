Safe lists SHOULD NOT be enabled.

Rationale: Messages sent from allowed safe list addresses bypass important security mechanisms, including spam filtering and sender authentication checks. Avoiding use of safe lists prevents potential threats from circumventing security mechanisms. While blocking all malicious senders is not feasible, blocking specific known, malicious IP addresses may reduce the threat from specific senders.

#### Remediation action:

To modify the connection filters, follow the instructions found in Use the Microsoft 365 Defender portal to modify the default connection filter policy.
1. Sign in to **Microsoft 365 Defender portal**.
2. From the left-hand menu, find **Email & collaboration** and select **Policies and Rules**.
3. Select **Threat Policies** from the list of policy names.
4. Under **Policies**, select [**Anti-spam**](https://security.microsoft.com/antispam).
5. Select **Connection filter policy (Default)**.
6. Click **Edit connection filter policy**.
8. Ensure **Turn on safe list** is not selected.

#### Related links

* [Defender admin center - Anti-spam policies](https://security.microsoft.com/antispam)
* [CISA Security Suite baseline - MS.SECURITYSUITE.8.2v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite82v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%