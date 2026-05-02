---
title: MT.1014 - At least one Conditional Access policy is configured to require compliant or Entra hybrid joined devices for admins
description: Checks if the tenant has at least one conditional access policy requiring device compliance for admins.
slug: /tests/MT.1014
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured to require compliant or Entra hybrid joined devices for admins

## Description

Checks if the tenant has at least one conditional access policy requiring device compliance for admins. Device compliance conditional access policy can be used to require devices to be compliant or Entra hybrid joined for admins. This is a good way to prevent AITM (adversary in the middle) attacks.

## How to fix

Create a conditional access policy that requires compliant or Entra hybrid joined devices for admins.

## Learn more

- [Require compliant or Microsoft Entra hybrid joined device for administrators](https://aka.ms/CATemplatesAdminDevices)
