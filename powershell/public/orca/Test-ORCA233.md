Exchange Online Protection (EOP) and Microsoft Defender for Office 365 (MDO) works best when the mail exchange (MX) record is pointed directly at the service. In the event another third-party service is being used, a very important signal (the senders IP address) is obfuscated and hidden from EOP & MDO, generating a larger quantity of false positives and false negatives. By configuring Enhanced Filtering with the IP addresses of these services the true senders IP address can be discovered, reducing the false-positive and false-negative impact.

#### Remediation action
Send mail directly to EOP or configure enhanced filtering.

#### Related Links

* [Enhanced Filtering for Connectors](https://aka.ms/orca-connectors-docs-1) 
* [Microsoft 365 Defender Portal - Enhanced Filtering](https://aka.ms/orca-connectors-action-skiplisting)
