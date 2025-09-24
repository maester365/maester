Ensure none or less than 100 outbound mails per day are being sent using the .onmicrosoft.com domain.

Limitations of free 'onmicrosoft' shared domains:\
The "default" onmicrosoft domains are useful for testing mail flow but are not suitable for regular messaging. They do not reflect a customer's brand identity and offer limited administrative control. Moreover, because these domains all share the 'onmicrosoft' domain (for example, 'contoso.onmicrosoft.com'), their reputation is collectively impacted. Despite Microsoft's efforts to minimize abuse, spammers often exploit newly created tenants to send bursts of spam from '.onmicrosoft.com' addresses before they can intervene. This degrades this shared domain's reputation, affecting all legitimate users. To ensure brand trust and email deliverability, organizations should establish and use their own custom domains for sending email. Until now, Microsoft did not have any limits on use of MOERA domains for email delivery.

Introducing new throttling enforcement:\
To **prevent misuse and help improve deliverability** of customer email by encouraging best practices, Microsoft is changing its policy. In the future, MOERA domains should only be used for testing purposes, not regular email sending. Microsoft will be **introducing throttling to limit messages** sent from 'onmicrosoft.com' domains to **100 external recipients per organization per 24 hour** rolling window. Inbound messages won't be affected. External recipients are counted after the expansion of any of the original recipients. When a sender hits the throttling limit, they will receive NDRs with the code **550 5.7.236** for any attempts to send to external recipients while the tenant is throttled.

Rollout timeline:\
| MOERA outgoing email throttling starts | Exchange seats in the tenant |
| --- | --- |
| October 15, 2025 | Trial |
| December 1, 2025 | < 3 |
| January 7, 2026 | 3 - 10 |
| February 2, 2026 | 11 - 50 |
| March 2, 2026 | 51 - 200 |
| April 1, 2026 | 201 - 2.000 |
| May 4, 2026 | 2.001 - 10.000 |
| June 1, 2026 | 10.001 > |

Post origin from Exchange Team Blog, check your Message Center for further information on this change. [Exchange Team Blog](https://techcommunity.microsoft.com/blog/exchange/limiting-onmicrosoft-domain-usage-for-sending-emails/4446167?WT.mc_id=M365-MVP-5003086)

#### Remediation action:

Change primary usage of the .onmicrosoft.com domain for mailboxes.
1. Navigate to Exchange admin center [Exchange Admin Center](https://admin.exchange.microsoft.com/#/)
2. Click to expand **Recipients** and select **Mailboxes**.
3. Filter for mailboxes with the .onmicrosoft.com domain as a primary SMTP address.
4. Select a mailbox to open its properties and click **Manage email address types**.
5. Select **Add email address type** and add a new mail adress with your custom domain.
6. Check **Set as primary email address**.
7. Confirm with **Ok**.
8. Repeat for every mailbox.

#### Related links

* [Exchange Admin Center](https://admin.exchange.microsoft.com/#/)
* [Limiting Onmicrosoft Domain Usage for Sending Emails | Exchange Team Blog](https://techcommunity.microsoft.com/blog/exchange/limiting-onmicrosoft-domain-usage-for-sending-emails/4446167?WT.mc_id=M365-MVP-5003086)

<!--- Results --->
%TestResult%