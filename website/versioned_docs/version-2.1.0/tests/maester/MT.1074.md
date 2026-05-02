---
title: MT.1074 - Mailbox should not use the .onmicrosoft.com domain as primary SMTP address.
description: This test checks if any mailbox uses .onmicrosoft.com domain as primary SMTP address.
slug: /tests/MT.1074
sidebar_class_name: hidden
---

## Description

**MOERA domains for email:**\
When a organization creates a new tenant in Microsoft 365, an onmicrosoft.com domain (or similar default domain like onmicrosoft.de) is provided. These MOERA (Microsoft Online Email Routing Address) domains enable immediate connectivity and user creation. Having enabled a quick start and testing of a new tenant, customers are expected to add their own custom domains for better brand representation and control moving forward. Customers who continue using MOERA domains as their "primary domain" may face significant challenges.

**Limitations of free 'onmicrosoft' shared domains:**\
These "default" domains are useful for testing mail flow but are not suitable for regular messaging. They do not reflect a customer's brand identity and offer limited administrative control. Moreover, because these domains all share the 'onmicrosoft' domain (for example, 'contoso.onmicrosoft.com'), their reputation is collectively impacted. Despite our efforts to minimize abuse, spammers often exploit newly created tenants to send bursts of spam from '.onmicrosoft.com' addresses before we can intervene. This degrades this shared domain's reputation, affecting all legitimate users. To ensure brand trust and email deliverability, organizations should establish and use their own custom domains for sending email. Until now, we did not have any limits on use of MOERA domains for email delivery.

**Introducing new throttling enforcement:**\
To prevent misuse and help improve deliverability of customer email by encouraging best practices, we are changing our policy. In the future, MOERA domains should only be used for testing purposes, not regular email sending. We will be introducing throttling to limit messages sent from 'onmicrosoft.com' domains to 100 external recipients per organization per 24 hour rolling window. Inbound messages won't be affected. External recipients are counted after the expansion of any of the original recipients. When a sender hits the throttling limit, they will receive NDRs with the code 550 5.7.236 for any attempts to send to external recipients while the tenant is throttled.

## Learn more
* [Exchange Admin Center](https://admin.exchange.microsoft.com/#/)
* [Limiting Onmicrosoft Domain Usage for Sending Emails | Exchange Team Blog](https://techcommunity.microsoft.com/blog/exchange/limiting-onmicrosoft-domain-usage-for-sending-emails/4446167?WT.mc_id=M365-MVP-5003086)