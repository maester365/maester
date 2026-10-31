2.1.6 (L1) Ensure Exchange Online Spam Policies are set to notify administrators

In Microsoft 365 organizations with mailboxes in Exchange Online or standalone Exchange Online Protection (EOP) organizations without Exchange Online mailboxes, email messages are automatically protected against spam (junk email) by EOP. Configure Exchange Online Spam Policies to copy emails and notify someone when a sender in the organization has been blocked for sending spam emails.

The check evaluates the policy associated with the highest-priority enabled custom outbound spam rule when one exists; otherwise it evaluates the Default policy. Both recipient fields must contain at least one address.

#### Rationale

A blocked account is a good indication that the account in question has been breached, and an attacker is using it to send spam emails to other people.

#### Impact

Notification of users that have been blocked should not cause an impact to the user.

#### Remediation action

To set the Exchange Online Spam Policies:

1. Navigate to Microsoft 365 Defender [https://security.microsoft.com](https://security.microsoft.com)
2. Under **Email & collaboration** select **Policies & rules**
3. Select **Threat policies** then **Anti-spam**
4. Open the **Anti-spam outbound policy (default)**, unless the check identifies a higher-priority enabled custom policy.
5. Select **Edit protection settings** then under **Notifications**
6. Check **Send a copy of suspicious outbound messages or messages that exceed these limits to these users and groups** then enter the desired email addresses
7. Check **Notify these users and groups if a sender is blocked due to sending outbound spam** then enter the desired email addresses.
8. Click **Save**.

##### PowerShell

1. Connect to Exchange Online using `Connect-ExchangeOnline`.
2. Run the following PowerShell command:

```powershell
$BccEmailAddress = @("<INSERT-EMAIL>")
$NotifyEmailAddress = @("<INSERT-EMAIL>")
Set-HostedOutboundSpamFilterPolicy -Identity Default -BccSuspiciousOutboundAdditionalRecipients $BccEmailAddress -BccSuspiciousOutboundMail $true -NotifyOutboundSpam $true -NotifyOutboundSpamRecipients $NotifyEmailAddress
```

>Note: If the check identifies a custom policy, use that policy's identity in the PowerShell command. Review the reported addresses to confirm they are correct and monitored.

#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [Outbound spam protection for cloud mailboxes](https://learn.microsoft.com/defender-office-365/outbound-spam-protection-about)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - Page 99](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
