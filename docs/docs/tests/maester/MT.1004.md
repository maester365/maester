---
title: MT.1004
description: At least one Conditional Access policy is configured with All Cloud Apps and All Users
slug: /tests/MT.1004
---

# At least one Conditional Access policy is configured with `All cloud apps` and `All users`

## Description

Ensure that every app has at least one Conditional Access policy applied and it is assigned to `All users`. From a security perspective it's better to create a policy that encompasses `All cloud apps` and `All users`, and then exclude applications and users that you don't want the policy to apply to.

This practice ensures you

- Don't need to update Conditional Access policies every time you onboard a new application.
- Protect all Microsoft Graph API calls from apps that are not listed in the Apps blade in the Entra portal.
- Don't introduce gaps when new employees are onboarded or when ad hoc accounts are created in the tenant.

## How to fix

Create a conditional access policy that applies to `All cloud apps` + `All users`, and then exclude applications that you don't want the policy to apply to.

## Learn more

- [Apply Conditional Access policies to every app](https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access#apply-conditional-access-policies-to-every-app)
