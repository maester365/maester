---
title: MT.1016 - At least one Conditional Access policy is configured to require MFA for guest access
description: Checks if the tenant has at least one conditional access policy requiring multifactor authentication for all guest users.
slug: /tests/MT.1016
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured to require MFA for guest access

## Description

Checks if the tenant has at least one conditional access policy requiring multifactor authentication for all guest users. MFA for all users conditional access policy can be used to require MFA for all guest users in the tenant.

## How to fix

Create a conditional access policy that requires MFA for all guest users.

## Learn more

- [Require multifactor authentication for guest access](https://aka.ms/CATemplatesGuest)
