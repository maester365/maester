2.1.12 (L1) Ensure the connection filter IP allow list is not used

In Microsoft 365 organizations with Exchange Online mailboxes or standalone Exchange Online Protection (EOP) organizations without Exchange Online mailboxes, connection filtering and the default connection filter policy identify good or bad source email servers by IP addresses. The key components of the default connection filter policy are IP Allow List, IP Block List and Safe list.
The recommended state is **IP Allow List** empty or undefined.

#### Rationale

Without additional verification like mail flow rules, email from sources in the IP Allow List skips spam filtering and sender authentication (SPF, DKIM, DMARC) checks. This method creates a high risk of attackers successfully delivering email to the Inbox that would otherwise be filtered. Messages that are determined to be malware or high confidence phishing are filtered.

#### Impact

This is the default behavior. IP Allow lists may reduce false positives, however, this benefit is outweighed by the importance of a policy which scans all messages regardless of the origin. This supports the principle of zero trust.

#### Remediation action:

To remove IPs from the allow list:
1. Navigate to [Microsoft 365 Defender](https://security.microsoft.com).
2. Click to expand **Email & collaboration** select **Policies & rules** > **Threat policies**.
3. Under policies select **Anti-spam**.
4. Click on the **Connection filter policy (Default)**.
5. Click **Edit connection filter policy**.
6. Remove any IP entries from **Always allow messages from the following IP addresses or address range:**.
7. Click **Save**.

##### PowerShell

1. Connect to Exchange Online using `Connect-ExchangeOnline`.
2. Run the following PowerShell command:
```powershell
Set-HostedConnectionFilterPolicy -Identity Default -IPAllowList @{}
```

#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [Configure connection filtering in cloud organizations](https://learn.microsoft.com/en-us/defender-office-365/connection-filter-policies-configure)
* [Create sender allowlists for cloud mailboxes](https://learn.microsoft.com/en-us/defender-office-365/create-safe-sender-lists-in-office-365#use-the-ip-allow-list)
* [When user and organization settings conflict](https://learn.microsoft.com/en-us/defender-office-365/how-policies-and-protections-are-combined#user-and-tenant-settings-conflict)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 116](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%