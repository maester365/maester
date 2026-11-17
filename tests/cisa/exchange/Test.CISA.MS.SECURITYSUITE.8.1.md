IP allow lists SHOULD NOT be created.

Rationale: Messages sent from IP addresses on an allow list bypass important security mechanisms, including spam filtering and sender authentication checks. Avoiding use of IP allow lists prevents potential threats from circumventing security mechanisms.

#### Remediation action:

To modify the connection filters, follow the instructions found in Use the Microsoft 365 Defender portal to modify the default connection filter policy.
1. Sign in to **Microsoft 365 Defender portal**.
2. From the left-hand menu, find **Email & collaboration** and select **Policies and Rules**.
3. Select **Threat Policies** from the list of policy names.
4. Under **Policies**, select [**Anti-spam**](https://security.microsoft.com/antispam).
5. Select **Connection filter policy (Default)**.
6. Click **Edit connection filter policy**.
7. Ensure no addresses are specified under **Always allow messages from the following IP addresses or address range**.

#### Related links

* [Defender admin center - Anti-spam policies](https://security.microsoft.com/antispam)
* [CISA Security Suite baseline - MS.SECURITYSUITE.8.1v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite81v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%