---
title: MT.1031 - Privileged role on Control Plane are managed by PIM only
description: Checks if PIM alert for role assignments outside of Privileged Identity Management (PIM) exists
slug: /tests/MT.1031
sidebar_class_name: hidden
---

# Privileged role on Control Plane are managed by PIM only

## Description

Privileged role assignments made outside of Privileged Identity Management aren't properly monitored and may indicate an active attack.

_Note: By default, the check excludes emergency access (Break Glass) accounts which has been identified by Maester._

## How to fix

Review the users in the list and remove them from privileged roles that they don't need.
Notes in the Maester test results provide direct link to the alert page with details to identify and how to address the recommendations.

## Learn more

- [Details of PIM Alert "Roles are being assigned outside of Privileged Identity Management"](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-how-to-configure-security-alerts#roles-are-being-assigned-outside-of-privileged-identity-management)
