---
title: MT.1012 - At least one Conditional Access policy is configured to require MFA for risky sign-ins
description: Checks if the tenant has at least one conditional access policy requiring multifactor authentication for risky sign-ins.
slug: /tests/MT.1012
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured to require MFA for risky sign-ins

## Description

Checks if the tenant has at least one conditional access policy requiring multifactor authentication for risky sign-ins.

## How to fix

Create a risk based conditional access policy for risky sign-ins that can be used to require MFA when any user is detected to be at risk.

## Learn more

- [Conditional Access policy: Sign-in risk-based multifactor authentication](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk)
