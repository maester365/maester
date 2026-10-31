No mail flow rule sets the spam confidence level to -1 for mail from specific sender domains.

A spam confidence level of -1 tells Exchange Online to deliver the message without spam filtering. If the rule matches a sender domain, anyone who can spoof that domain, or who compromises it, sends mail straight to your users, with the same trust as an internal sender.

If a business exception is necessary, CIS says to whitelist the domain only when inbound mail from that domain originates from a specific IP address, and to document and regularly review the exception. The CIS PowerShell audit flags every rule that combines `SenderDomainIs` with `SetSCL -1`; this check does not verify an IP restriction or exception documentation, so assess each flagged rule against those conditions. Prefer fixing the cause of false positives, for example by configuring SPF, DKIM and DMARC for the partner domain.

#### Remediation action

1. Sign in to the [Exchange admin center](https://admin.exchange.microsoft.com).
2. Go to **Mail flow** > [**Rules**](https://admin.exchange.microsoft.com/#/transportrules).
3. Open each rule that is listed in the test result and remove the action **Set the spam confidence level (SCL) to Bypass spam filtering**, or delete the rule.

#### Related links

* [Exchange admin center - Mail flow rules](https://admin.exchange.microsoft.com/#/transportrules)
* [Use mail flow rules to set the spam confidence level](https://learn.microsoft.com/exchange/security-and-compliance/mail-flow-rules/mail-flow-rule-actions)
* [Create safe sender lists in Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/create-safe-sender-lists-in-office-365)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.2.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
