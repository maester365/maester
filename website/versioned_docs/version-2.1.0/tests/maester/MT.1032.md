---
title: MT.1032 - Limited number of Global Admins are assigned
description: Checks if PIM alert for too many Global Admins exists
slug: /tests/MT.1032
sidebar_class_name: hidden
---

# Limited number of Global Admins are assigned

## Description

Global administrator is the highest privileged role. If a Global Administrator is compromised, the attacker gains access to all of their permissions, which put your whole system at risk.

_Note: By default, the check excludes emergency access (Break Glass) accounts which has been identified by Maester._

## How to fix

Review the users in the list and remove them from privileged roles that they don't need.
Notes in the Maester test results provide direct link to the alert page with details to identify and how to address the recommendations.

## Learn more

- [Details of PIM Alert "There are too many global administrators"](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-how-to-configure-security-alerts#there-are-too-many-global-administrators)
