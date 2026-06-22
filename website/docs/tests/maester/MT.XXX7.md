---
title: MT.XXX7 - Microsoft Entra private network connector groups are redundant
description: Every in-use Microsoft Entra private network connector group should have at least two active connectors so a single connector outage does not break access.
slug: /tests/MT.XXX7
sidebar_class_name: hidden
---

# Microsoft Entra private network connector groups are redundant

## Description

Microsoft Entra private network connectors (shared by Application Proxy and Global Secure Access Private Access) should be deployed with redundancy. Every connector group that serves traffic should contain at least **two active connectors on separate hosts**, so that a single connector outage does not break access to the applications the group serves.

Connector groups with no connectors are treated as unused (for example the Default onboarding pool) and are not evaluated.

## How to fix

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Global Secure Access Administrator.
2. Browse to **Global Secure Access** > **Connect** > **Connectors**.
3. Install at least one additional connector on a **separate host** and add it to each flagged connector group.

## Learn more

- [Microsoft Entra private network connectors](https://learn.microsoft.com/entra/global-secure-access/concept-connectors)
- [Optimize connector groups for high availability and load balancing](https://learn.microsoft.com/entra/identity/app-proxy/application-proxy-connector-groups)
