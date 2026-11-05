Sending domains must publish an SPF record that ends in a hard fail (-all) or soft fail (~all). Parked or otherwise non-sending domains must publish an SPF policy that denies all senders with -all.

SPF lists the servers that may send mail for a domain. Receiving servers use it to reject, or to mark as suspicious, mail that pretends to come from your domain. Without an SPF record, or with one that ends in a neutral or permissive qualifier, anyone can send mail that looks like it comes from you without raising a flag.

Maester identifies a likely non-sending domain when it finds one SPF v1 record with only a non-authorizing `-all` or `~all` mechanism, no Exchange DKIM signing configuration, and no selector1 or selector2 DKIM CNAME/TXT record. An SPF record ending in `?all` is inconclusive and does not establish that the domain is unused. It classifies the domain as parked only when the non-sending signals are also accompanied by no usable MX route (or a null MX) and no A, AAAA, or CNAME record at the domain apex. This conservative DNS assessment does not use `AcceptedDomain.SendingFromDomainDisabled`.

For a parked or non-sending domain, the SPF record must explicitly use `-all`; a `~all` policy does not meet the parked-domain audit. For sending domains, the test follows a redirect modifier only when the record has no all mechanism, since receivers ignore the redirect in that case. Domains in the onmicrosoft.com namespace are skipped.

Missing SPF, conflicting signals, DNS errors, and unresolved redirect-only policies do not receive the parked exception. When the record passes the sending-domain rule but could fail the parked-domain rule, the result requires investigation. Selector discovery is limited to the standard Exchange Online selectors, so nonstandard DKIM selector names cannot be ruled out automatically.

When some lookups are unavailable and another domain requires investigation, the result remains Investigate and lists the unavailable domains as Not checked. This is not confirmation of compliance for those domains. Known failures still take precedence; unavailable lookups without failures or investigation produce NotSupported.

When DNS evidence is inconclusive but a domain is known to be parked, add its name to this test's `ParkedDomains` parameter in `TestSettings[].Parameters`. This selects the parked audit branch; it does not waive the requirement to publish `v=spf1 -all`.

#### Remediation action

1. Open the DNS zone of each custom domain at your DNS host.
2. Create or edit the TXT record at the domain root. For a sending domain, list its sending services and end with `-all` or `~all`; for a parked or non-sending domain, publish `v=spf1 -all`. For Exchange Online only, use `v=spf1 include:spf.protection.outlook.com -all`.
3. Wait for the change to propagate and check the record with `Resolve-DnsName -Name <domain> -Type TXT`.

#### Related links

* [Set up SPF to help prevent spoofing](https://learn.microsoft.com/defender-office-365/email-authentication-spf-configure)
* [Email authentication in Microsoft 365](https://learn.microsoft.com/defender-office-365/email-authentication-about)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.8](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
