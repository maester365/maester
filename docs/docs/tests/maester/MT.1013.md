---
title: MT.1013 - At least one Conditional Access policy is configured to require new password when user risk is high
description: Checks if the tenant has at least one conditional access policy requiring password change for high user risk. Password change for high user risk is a good way to prevent compromised accounts from being used to access your tenant.
slug: /tests/MT.1013
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured to require new password when user risk is high

## Description

Checks if the tenant has at least one conditional access policy requiring password change for high user risk. Password change for high user risk is a good way to prevent compromised accounts from being used to access your tenant.

## How to fix

Create a risk based conditional access policy for high user risk that can be used to require a password change when any user is detected to be at high risk.

## Learn more

- [Conditional Access policy: User risk-based password change](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk-user)
