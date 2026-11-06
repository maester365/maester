Every accepted domain, including the initial onmicrosoft.com domain, must meet the applicable DMARC audit. Sending domains require a quarantine or reject policy that covers all mail and names addresses for aggregate and forensic reports. Parked or otherwise non-sending domains require a valid DMARC record with `p=reject`.

DMARC tells receiving servers what to do with mail that fails SPF and DKIM alignment, and sends you reports about who is sending mail in your name. With a policy of none, spoofed mail is still delivered. Quarantine or reject stops it, and the reports show abuse and legitimate senders that you forgot.

The test uses the record at the domain, or at its organisational domain (for example contoso.com for mail.contoso.com) when the domain has no valid record, including a malformed record, applying the subdomain policy where one exists. For sending domains, the policy must apply to 100 percent of mail (no pct tag, or pct=100), and both rua and ruf addresses must be mailto addresses.

Maester identifies a likely non-sending domain when it finds one SPF v1 record with only a non-authorizing `-all` or `~all` mechanism, no Exchange DKIM signing configuration, and no selector1 or selector2 DKIM CNAME/TXT record. An SPF record ending in `?all` is inconclusive and does not establish that the domain is unused. It classifies the domain as parked only when the non-sending signals are also accompanied by no usable MX route (or a null MX) and no A, AAAA, or CNAME record at the domain apex. This conservative DNS assessment does not use `AcceptedDomain.SendingFromDomainDisabled`.

Parked or non-sending domains use the CIS parked-domain requirement: a valid DMARC record with `p=reject`; rua, ruf, and pct are not required for this branch. Missing SPF, conflicting signals, DNS errors, and unresolved redirect-only SPF policies do not receive the parked exception. When only one of the sending and non-sending audit procedures passes, the result requires investigation. Selector discovery is limited to the standard Exchange Online selectors, so nonstandard DKIM selector names cannot be ruled out automatically.

When some lookups are unavailable and another domain requires investigation, the result remains Investigate and lists the unavailable domains as Not checked. Investigation results state that compliance remains unconfirmed and direct you to review these domains instead of displaying a full-compliance banner. Known failures still take precedence; unavailable lookups without failures or investigation produce NotSupported.

When DNS evidence is inconclusive but a domain is known to be parked, add its name to this test's `ParkedDomains` parameter in `TestSettings[].Parameters`. This selects the parked audit branch; it does not waive the requirement for a valid DMARC record with `p=reject`.

#### Remediation action

1. Open the DNS zone of each custom domain at your DNS host. For the initial `*.onmicrosoft.com` domain, use the Microsoft 365 admin center instead: go to **Settings** > **Domains**, select the `*.onmicrosoft.com` domain, open the **DNS records** tab and select **Add record**.
2. Create or edit the TXT record `_dmarc.<domain>` (in the admin center, the host name is `_dmarc`). For a sending domain, use a value such as `v=DMARC1; p=reject; pct=100; rua=mailto:dmarc-reports@<domain>; ruf=mailto:dmarc-forensic@<domain>`. For a parked or non-sending domain, `v=DMARC1; p=reject` meets the parked-domain requirement.
3. Start with `p=none` or `p=quarantine` if you are not sure that all your senders are aligned, review the reports and then move to `p=reject`.
4. Check the record with `Resolve-DnsName -Name _dmarc.<domain> -Type TXT`.

#### Related links

* [Use DMARC to validate email](https://learn.microsoft.com/defender-office-365/email-authentication-dmarc-configure)
* [Email authentication in Microsoft 365](https://learn.microsoft.com/defender-office-365/email-authentication-about)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.10](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
