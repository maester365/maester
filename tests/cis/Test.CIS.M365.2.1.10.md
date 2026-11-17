Every accepted domain, including the initial onmicrosoft.com domain, must meet the applicable DMARC audit. Sending domains require a quarantine or reject policy that covers all mail and names addresses for aggregate and forensic reports. Parked domains, which don't send email, require a valid DMARC record with `p=reject`.

DMARC tells receiving servers what to do with mail that fails SPF and DKIM alignment, and sends you reports about who is sending mail in your name. With a policy of none, spoofed mail is still delivered. Quarantine or reject stops it, and the reports show abuse and legitimate senders that you forgot.

The test uses the record at the domain, or at its organisational domain (for example contoso.com for mail.contoso.com) when the domain has no valid record, including a malformed record, applying the subdomain policy where one exists. For sending domains, the policy must apply to 100 percent of mail (no pct tag, or pct=100), and both rua and ruf addresses must be mailto addresses.

Maester does not guess which domains are parked. CIS leaves that to the person running the audit, so set the shared `GlobalSettings.ParkedDomains` list in the Maester config for all three checks. A per-test `ParkedDomains` value in `TestSettings[].Parameters` overrides the shared list for that check. Every other domain gets the sending-domain audit.

The engine binds this setting to the test parameter and validates entries as domain names. An explicit empty per-test list overrides the shared list, so every domain in that check receives the sending-domain audit.

Parked domains use the CIS parked-domain requirement: a valid DMARC record with `p=reject`; rua, ruf and pct are not required. When the DNS lookup is not available for a domain, it is listed as Not checked.

#### Remediation action

1. Open the DNS zone of each custom domain at your DNS host. For the initial `*.onmicrosoft.com` domain, use the Microsoft 365 admin center instead: go to **Settings** > **Domains**, select the `*.onmicrosoft.com` domain, open the **DNS records** tab and select **Add record**.
2. Create or edit the TXT record `_dmarc.<domain>` (in the admin center, the host name is `_dmarc`). For a sending domain, use a value such as `v=DMARC1; p=reject; pct=100; rua=mailto:dmarc-reports@<domain>; ruf=mailto:dmarc-forensic@<domain>`. For a parked domain, `v=DMARC1; p=reject` meets the parked-domain requirement; add the domain to `ParkedDomains`.
3. Start with `p=none` or `p=quarantine` if you are not sure that all your senders are aligned, review the reports and then move to `p=reject`.
4. Check the record with `Resolve-DnsName -Name _dmarc.<domain> -Type TXT`.

#### Related links

* [Use DMARC to validate email](https://learn.microsoft.com/defender-office-365/email-authentication-dmarc-configure)
* [Email authentication in Microsoft 365](https://learn.microsoft.com/defender-office-365/email-authentication-about)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.10](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
