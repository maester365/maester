---
title: MT.1192 - Groups assigned to Entra Private Access applications are not nested
description: Enterprise app assignment grants access to direct group members only, so groups assigned to Private Access and Quick Access applications must use direct membership.
slug: /tests/MT.1192
sidebar_class_name: hidden
---

# Groups assigned to Entra Private Access applications are not nested

## Description

Microsoft Entra enterprise application assignment grants access to the **direct** (and dynamic) members of an assigned group only - the assignment does **not** cascade to nested groups, and nested group membership is not supported for app assignment. Groups assigned to Global Secure Access Private Access applications (and the Quick Access app) must therefore use direct membership, otherwise members of a nested group are silently left without access.

This limitation applies only to app assignment. Conditional Access scoping does honor nested groups, so the MFA and managed-device coverage checks are not affected.

## How to fix

1. Identify the flagged Private Access / Quick Access application assignment group(s).
2. Either flatten the group to direct (or dynamic) membership, or assign the nested group(s) to the application directly.
3. Re-test to confirm that no assignment group contains a nested group.

## Learn more

- [Assign users and groups to an application](https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-or-group-access-portal)
- [Use a group to manage access to applications](https://learn.microsoft.com/entra/identity/users/groups-saasapps)
