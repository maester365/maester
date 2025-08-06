---
title: MT.1072 - No conditional access policy should require an approved client app.
description: This test checks if there are any Conditional Access policies that require an approved client app.
slug: /tests/MT.1072
sidebar_class_name: hidden
---

## Description

Checks if the tenant has no conditional access policy that requires an approved client app.

The approved client app grant is retiring in early March 2026. Organizations must transition all current Conditional Access policies that use only the Require Approved Client App grant control to Require Approved Client App or Application Protection Policy by March 2026. Additionally, for any new Conditional Access policy, only apply the Require application protection policy grant.

After March 2026, Microsoft will stop enforcing require approved client app control, and it will be as if this grant isn't selected. Use the following steps before March 2026 to protect your organization’s data.

## Learn more
- [Migrate approved client app to application protection policy in Conditional Access](https://learn.microsoft.com/en-us/entra/identity/conditional-access/migrate-approved-client-app)