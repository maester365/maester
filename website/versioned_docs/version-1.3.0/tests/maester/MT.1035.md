---
title: MT.1035 - All security groups assigned to Conditional Access Policies should be protected by RMAU
description: Checks if groups used in Conditional Access are protected by either Restricted Management Administrative Units or Role Assignable Groups
slug: /tests/MT.1035
sidebar_class_name: hidden
---

# All security groups assigned to Conditional Access Policies should be protected by RMAU

## Description

Security Groups will be used to exclude and include users from Conditional Access Policies.
Modify group membership outside of Conditional Access Administrator or other privileged roles can lead to bypassing Conditional Access Policies. To prevent this, you can protect these groups by using Restricted Management Administrative Units or Role Assignable Groups. Role Assignable Group should be used in combination of assignments to Entra ID roles. Restricted Management Administrative Units should be used to protect groups by restricting management to specific users or groups. This test checks if all groups used in Conditional Access Policies are protected.

## How to fix

Assign security groups to Restricted Management Administrative Unit (RMAU).

## Learn more
  - [Microsoft Learn | Restricted management administrative units in Microsoft Entra ID (Preview)](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/admin-units-restricted-management)
  - [janbakker.tech | Prevent Conditional Access bypass with Restricted Management Administrative Units in Entra ID](https://janbakker.tech/prevent-conditional-access-bypass-with-restricted-management-administrative-units-in-entra-id/)
  - [Cloud-Architekt.net | Protection of privileged users and groups by Azure AD Restricted Management Administrative Units](https://www.cloud-architekt.net/restricted-management-administrative-unit/)
