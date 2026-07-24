---
title: MT.1193 - Entra Private Access application segments avoid broad or risky destinations
description: Private Access application segments should target specific destinations - dnsSuffix, wildcard, single-label FQDN, and broad IPv4 ranges break least-privilege.
slug: /tests/MT.1193
sidebar_class_name: hidden
---

# Entra Private Access application segments avoid broad or risky destinations

## Description

Entra Private Access application segments should target specific destinations. Broad or risky destinations break least-privilege and can cause operational problems:

- **`dnsSuffix`** - a broad namespace catch-all that commonly masks a missing or incorrect Private DNS suffix.
- **Wildcard FQDN** (for example `*.contoso.com`).
- **Single-label FQDN** (for example `fileserver`) - relies on the synthetic Global Secure Access suffix and carries a Kerberos SPN risk.
- **Broad IP ranges** (near-default routes). The portal's broadest selectable mask is `/1`, so segments *broader than* `/16` are flagged - a `/16`, common for 10.x networks, still passes. Global Secure Access is IPv4-only, so IPv6 is not evaluated.

## How to fix

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Global Secure Access Administrator.
2. Browse to **Global Secure Access** > **Applications** > **Enterprise applications** and open each flagged application.
3. Replace the broad segment with specific FQDNs / IP ranges, and configure the correct Private DNS suffix instead of relying on a `dnsSuffix` catch-all.

## Learn more

- [Configure per-app access using Global Secure Access applications](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-per-app-access)
- [How to configure Quick Access](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-quick-access)
