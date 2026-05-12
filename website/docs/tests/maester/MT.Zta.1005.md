---
title: MT.Zta.1005 - Network pillar fail count is below the warn threshold
description: "ZTA's **Network pillar** covers Global Secure Access (GSA), private-network access, internet access policy, and network-aware conditional access. Bulk failures here usually mean GSA is not deployed, or GSA tunnels are mis-scoped."
slug: /tests/MT.Zta.1005
sidebar_class_name: hidden
---

# Network pillar fail count is below the warn threshold

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.PillarFocus.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.PillarFocus.Tests.ps1) |

## Description

ZTA's **Network pillar** covers Global Secure Access (GSA), private-network access, internet access policy, and network-aware conditional access. Bulk failures here usually mean GSA is not deployed, or GSA tunnels are mis-scoped.
## How to fix

1. Entra ID → Global Secure Access — verify the tenant is enrolled and at least one of {Microsoft Traffic, Internet Access, Private Access} is provisioned.
2. CA — verify a network-aware policy enforces GSA for in-scope users.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)