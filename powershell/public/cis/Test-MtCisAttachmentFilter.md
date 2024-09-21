2.1.2 (L1) Ensure the Common Attachment Types Filter is enabled

**Rationale:**

Blocking known malicious file types can help prevent malware-infested files from infecting a host.

#### Remediation action:

Ensure the Common Attachment Types Filter is enabled:
1. Navigate to Microsoft 365 Defender [https://security.microsoft.com](https://security.microsoft.com).
2. Click to expand **Email & collaboration** select **Policies & rules**.
3. On the Policies & rules page select **Threat policies**.
4. Under polices select **Anti-malware** and click on the **Default (Default)** policy.
5. On the policy page that appears on the righthand pane, under **Protection settings**, verify that the **Enable the common attachments filter** has the value of **On**.

#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v3.1.0 - Page 33](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%