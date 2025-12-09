2.1.4 (L2) Ensure Safe Attachments policy is enabled

**Rationale:**
Enabling Safe Attachments policy helps protect against malware threats in email attachments by analyzing suspicious attachments in a secure, cloud-based environment before they are delivered to the user's inbox. This provides an additional layer of security and can prevent new or unseen types of malware from infiltrating the organization's network.

#### Remediation action:

To enable the Safe Attachments policy:
1. Navigate to Microsoft 365 Defender [https://security.microsoft.com](https://security.microsoft.com).
2. Click to expand **E-mail & Collaboration** select **Policies & rules**.
3. On the Policies & rules page select **Threat policies**.
4. Under **Policies** select **Safe Attachments**.
5. Click + **Create**.
6. Create a Policy Name and Description, and then click **Next**.
7. Select all valid domains and click Next.
8. Select **Block**.
9. Quarantine policy is **AdminOnlyAccessPolicy**.
10. Leave **Enable redirect** unchecked.
11. Click **Next** and finally **Submit**.

#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 80](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%