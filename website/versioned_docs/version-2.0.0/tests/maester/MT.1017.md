---
title: MT.1017 - At least one Conditional Access policy is configured to enforce non persistent browser session for non-corporate devices
description: Non persistent browser session conditional access policy can be helpful to minimize the risk of data leakage from a shared device.
slug: /tests/MT.1017
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured to enforce non persistent browser session for non-corporate devices

## Description

Non persistent browser session conditional access policy can be helpful to minimize the risk of data leakage from a shared device. Checks if the tenant has at least one conditional access policy enforcing non persistent browser session.

## How to fix

Create a conditional access policy to protect user access on unmanaged devices by preventing browser sessions from remaining signed in after the browser is closed.

## Learn more

- [Require reauthentication and disable browser persistence](https://aka.ms/CATemplatesBrowserSession)
