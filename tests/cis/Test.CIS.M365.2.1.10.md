Every accepted domain, including the initial onmicrosoft.com domain, has a DMARC policy of quarantine or reject that covers all mail and names addresses for aggregate and forensic reports.

DMARC tells receiving servers what to do with mail that fails SPF and DKIM alignment, and sends you reports about who is sending mail in your name. With a policy of none, spoofed mail is still delivered. Quarantine or reject stops it, and the reports show abuse and legitimate senders that you forgot.

The test uses the record at the domain, or at its parent domain when the domain has none, applying the subdomain policy where one exists. The policy must apply to 100 percent of mail (no pct tag, or pct=100). Both rua and ruf addresses must be mailto addresses. Move to enforcement in steps and review the aggregate reports first.

#### Remediation action

1. Open the DNS zone of each custom domain at your DNS host. For the initial `*.onmicrosoft.com` domain, use the Microsoft 365 admin center instead: go to **Settings** > **Domains**, select the `*.onmicrosoft.com` domain, open the **DNS records** tab and select **Add record**.
2. Create or edit the TXT record `_dmarc.<domain>` (in the admin center, the host name is `_dmarc`) with a value such as `v=DMARC1; p=reject; pct=100; rua=mailto:dmarc-reports@<domain>; ruf=mailto:dmarc-forensic@<domain>`.
3. Start with `p=none` or `p=quarantine` if you are not sure that all your senders are aligned, review the reports and then move to `p=reject`.
4. Check the record with `Resolve-DnsName -Name _dmarc.<domain> -Type TXT`.

#### Related links

* [Use DMARC to validate email](https://learn.microsoft.com/defender-office-365/email-authentication-dmarc-configure)
* [Email authentication in Microsoft 365](https://learn.microsoft.com/defender-office-365/email-authentication-about)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.10](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
