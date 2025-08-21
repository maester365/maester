Ensure mailboxes do not use the .onmicrosoft.com domain as primary SMTP address

MOERA domains for email:\
When a organization creates a new tenant in Microsoft 365, an onmicrosoft.com domain (or similar default domain like onmicrosoft.de) is provided. These MOERA (Microsoft Online Email Routing Address) domains enable immediate connectivity and user creation. Having enabled a quick start and testing of a new tenant, customers are expected to add their own custom domains for better brand representation and control moving forward. Customers who continue using MOERA domains as their "primary domain" may face significant challenges.

Limitations of free 'onmicrosoft' shared domains:\
These "default" domains are useful for testing mail flow but are not suitable for regular messaging. They do not reflect a customer's brand identity and offer limited administrative control. Moreover, because these domains all share the 'onmicrosoft' domain (for example, 'contoso.onmicrosoft.com'), their reputation is collectively impacted. Despite our efforts to minimize abuse, spammers often exploit newly created tenants to send bursts of spam from '.onmicrosoft.com' addresses before we can intervene. This degrades this shared domain's reputation, affecting all legitimate users. To ensure brand trust and email deliverability, organizations should establish and use their own custom domains for sending email. Until now, we did not have any limits on use of MOERA domains for email delivery.

Introducing new throttling enforcement:\
To prevent misuse and help improve deliverability of customer email by encouraging best practices, we are changing our policy. In the future, MOERA domains should only be used for testing purposes, not regular email sending. We will be introducing throttling to limit messages sent from 'onmicrosoft.com' domains to 100 external recipients per organization per 24 hour rolling window. Inbound messages won't be affected. External recipients are counted after the expansion of any of the original recipients. When a sender hits the throttling limit, they will receive NDRs with the code 550 5.7.236 for any attempts to send to external recipients while the tenant is throttled.

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

#### Remediation action:

Remove primary usage of the .onmicrosoft.com domain for mailboxes.
1. Navigate to Exchange admin center [Exchange Admin Center](https://admin.exchange.microsoft.com/#/)
2. Click to expand **Recipients** and select **Mailboxes**.
3. Filter for mailboxes with the .onmicrosoft.com domain as a primary SMTP address.
4. Select a maiblox to open its properties and click **Manage email address types**.
5. Select **Add email address type** and add a new mail adress with your custom domain.
6. Check **Set as primary email address**.
7. Confirm with **Ok**.
8. Repeat for every mailbox.

#### Related links

* [Exchange Admin Center](https://admin.exchange.microsoft.com/#/)
* [Limiting Onmicrosoft Domain Usage for Sending Emails | Exchange Team Blog](https://techcommunity.microsoft.com/blog/exchange/limiting-onmicrosoft-domain-usage-for-sending-emails/4446167?WT.mc_id=M365-MVP-5003086)

<!--- Results --->
%TestResult%