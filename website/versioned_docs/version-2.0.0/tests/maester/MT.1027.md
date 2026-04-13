---
title: MT.1027 - No Service Principal with Client Secret and permanent role assignment on Control Plane
description: Checks if External user have no high-privileged roles
slug: /tests/MT.1027
sidebar_class_name: hidden
---

# No Service Principal with Client Secret and permanent role assignment on Control Plane

## Description

Permanent Assignments of high-privileged Entra ID directory roles will be checked to identify privileges service principals with client secrets. Related roles will be identified based on the classification model from the [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM) project which helps to identify directory roles with Control Plane (Tier0) permissions.

## How to fix

It's recommended to use certificates for Service Principals.
Review if you can replace client secrets by certificates or use managed identities instead of a Service Principal.

## Learn more

  - [Securing service principals in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/architecture/service-accounts-principal#service-principal-authentication)
  - [Best practices for all isolation architectures - Service Principal Credentials](https://learn.microsoft.com/en-us/entra/architecture/secure-best-practices#service-principals-credentials)
