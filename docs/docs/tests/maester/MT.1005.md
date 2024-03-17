---
title: MT.1005 - All Conditional Access policies are configured to exclude at least one emergency account or group.
description: Checks if the tenant has at least one emergency/break glass account or account group excluded from all conditional access policies
slug: /tests/MT.1005
sidebar_class_name: hidden
---

# All Conditional Access policies are configured to exclude at least one emergency account or group

## Description

Checks if the tenant has at least one emergency/break glass account or account group excluded from all conditional access policies

## How to fix

It is recommended to have at least one emergency/break glass account or account group excluded from all conditional access policies.

This allows for emergency access to the tenant in case of a misconfiguration or other issues.

## Learn more

- [Manage emergency access accounts in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)
