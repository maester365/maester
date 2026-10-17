Every custom domain that is accepted by Exchange Online publishes an SPF record that ends in a hard fail (-all) or soft fail (~all).

SPF lists the servers that may send mail for a domain. Receiving servers use it to reject, or to mark as suspicious, mail that pretends to come from your domain. Without an SPF record, or with one that ends in a neutral or permissive qualifier, anyone can send mail that looks like it comes from you without raising a flag.

The test follows a single redirect modifier. Domains in the onmicrosoft.com namespace are skipped. Parked domains that never send mail should publish a record of "v=spf1 -all".

#### Remediation action

1. Open the DNS zone of each custom domain at your DNS host.
2. Create or edit the TXT record at the domain root so that it lists your sending services and ends with `-all` (or `~all`). For Exchange Online only, use `v=spf1 include:spf.protection.outlook.com -all`.
3. Wait for the change to propagate and check the record with `Resolve-DnsName -Name <domain> -Type TXT`.

#### Related links

* [Set up SPF to help prevent spoofing](https://learn.microsoft.com/defender-office-365/email-authentication-spf-configure)
* [Email authentication in Microsoft 365](https://learn.microsoft.com/defender-office-365/email-authentication-about)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.8](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
