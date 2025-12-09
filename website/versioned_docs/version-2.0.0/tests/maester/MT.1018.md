---
title: MT.1018 - At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices
description: Checks if the tenant has at least one conditional access policy enforcing sign-in frequency for non-corporate devices
slug: /tests/MT.1018
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices

## Description

Checks if the tenant has at least one conditional access policy enforcing sign-in frequency for non-corporate devices

## How to fix

Create a conditional access policy to protect user access on unmanaged devices by requiring a sign in frequency of 1 hour.

## Learn more

- [Require reauthentication and disable browser persistence](https://aka.ms/CATemplatesBrowserSession)
