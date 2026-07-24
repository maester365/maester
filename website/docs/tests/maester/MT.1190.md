---
title: MT.1190 - Entra Private Access applications do not use the Default connector group
description: Entra Private Access applications should be served through a dedicated connector group, not the Default group that new connectors automatically join.
slug: /tests/MT.1190
sidebar_class_name: hidden
---

# Entra Private Access applications do not use the Default connector group

## Description

Newly installed Microsoft Entra private network connectors automatically join the **Default** connector group. If an Entra Private Access application is served by the Default group, a freshly installed or misconfigured connector immediately begins handling its traffic - a routing and outage risk. Keep the Default group as an idle / onboarding pool and serve every Private Access application through a dedicated connector group.

## How to fix

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Global Secure Access Administrator.
2. Browse to **Global Secure Access** > **Applications** > **Enterprise applications** and open each flagged application.
3. Reassign it from the **Default** connector group to a dedicated connector group.

## Learn more

- [Microsoft Entra private network connector groups](https://learn.microsoft.com/entra/global-secure-access/concept-connectors)
- [Publish Enterprise apps with Global Secure Access](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-per-app-access)
