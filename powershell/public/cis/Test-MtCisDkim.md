2.1.9 (L1) Ensure that DKIM is enabled for all Exchange Online Domains

Description: DKIM lets an organization add a digital signature to outbound email messages in the message header.

#### Remediation action:

To enable DKIM:

1. Navigate to Microsoft 365 Defender [https://security.microsoft.com](https://security.microsoft.com)
2. Under **Email & collaboration** select **Policies & rules** then **Threat policies**
3. Under the **Rules** section click **Email authentication settings**
4. Select **DKIM**
5. Click on each domain and confirm that **Sign messages for this domain with DKIM signatures** is **Enabled**
6. A status of **Not signing DKIM signatures for this domain** is an audit fail.

#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 98](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%