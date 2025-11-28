---
title: MT.1030 - Eligible role assignments on Control Plane are in use by administrators
description: Checks if PIM alert for unused privileged roles exists
slug: /tests/MT.1030
sidebar_class_name: hidden
---

# Eligible role assignments on Control Plane are in use by administrators

## Description

Users that have been assigned privileged roles they don't need increases the chance of an attack. It's also easier for attackers to remain unnoticed in accounts that aren't actively being used.

_Note: By default, the check excludes emergency access (Break Glass) accounts which has been identified by Maester._

## How to fix

Review the users in the list and remove them from privileged roles that they don't need.
Notes in the Maester test results provide direct link to the alert page with details to identify and how to address the recommendations.

## Learn more

- [Details of PIM Alert "Administrators aren't using their privileged roles"](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-how-to-configure-security-alerts#administrators-arent-using-their-privileged-roles)
