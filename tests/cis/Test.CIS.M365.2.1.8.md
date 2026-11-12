Sending domains must publish an SPF record that ends in a hard fail (-all) or soft fail (~all). Parked domains, which don't send email, must publish `v=spf1 -all`, which denies all senders.

SPF lists the servers that may send mail for a domain. Receiving servers use it to reject, or to mark as suspicious, mail that pretends to come from your domain. Without an SPF record, or with one that ends in a neutral or permissive qualifier, anyone can send mail that looks like it comes from you without raising a flag.

Maester does not guess which domains are parked. CIS leaves that to the person running the audit, so set the shared `GlobalSettings.ParkedDomains` list in the Maester config for all three checks. A per-test `ParkedDomains` value in `TestSettings[].Parameters` overrides the shared list for that check. Every other domain gets the sending-domain audit.

The engine binds this setting to the test parameter and validates entries as domain names. An explicit empty per-test list overrides the shared list, so every domain in that check receives the sending-domain audit.

For a parked domain the record must be `v=spf1 -all`; a `~all` policy does not meet the parked-domain audit. For sending domains, the test follows a redirect modifier only when the record has no all mechanism, since receivers ignore the redirect in that case. Domains in the onmicrosoft.com namespace are skipped.

An `exp=` modifier does not authorize senders. A parked-domain record may include one before `-all`, but its domain-spec must have valid RFC 7208 syntax: `exp=explain._spf.%{d}` is valid, while `exp=%(d).example.com` is not. The check validates syntax without expanding macros or looking up the explanation text. The audit still requires the compliant all mechanism to be the final term: `v=spf1 -all exp=why.example.com` does not meet that termination requirement. An earlier `all` mechanism ends SPF evaluation before a later qualifier, so a record such as `v=spf1 all include:vendor.example -all` does not meet the audit.

#### Remediation action

1. Open the DNS zone of each custom domain at your DNS host.
2. Create or edit the TXT record at the domain root. For a sending domain, list its sending services and end with `-all` or `~all`; for a parked domain, publish `v=spf1 -all` and add the domain to `ParkedDomains`. For Exchange Online only, use `v=spf1 include:spf.protection.outlook.com -all`.
3. Wait for the change to propagate and check the record with `Resolve-DnsName -Name <domain> -Type TXT`.

#### Related links

* [Set up SPF to help prevent spoofing](https://learn.microsoft.com/defender-office-365/email-authentication-spf-configure)
* [Email authentication in Microsoft 365](https://learn.microsoft.com/defender-office-365/email-authentication-about)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.8](https://www.cisecurity.org/benchmark/microsoft_365)
* [RFC 7208 - SPF macro syntax](https://www.rfc-editor.org/rfc/rfc7208.html#section-7)

<!--- Results --->
%TestResult%
