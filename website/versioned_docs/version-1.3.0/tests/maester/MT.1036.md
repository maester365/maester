---
title: MT.1036 - All excluded objects should have a fallback include in another policy.
description: Checks for gaps in conditional access policies, by looking for excluded objects which are not specifically inlcuded in another conditional access policy. This way we try to spot possibly overlooked exclusions which do not have a fallback.
slug: /tests/MT.1036
sidebar_class_name: hidden
---

# All excluded objects should have a fallback include in another policy

## Description

Excluding specific users, groups, applications, or locations from a Conditional Access (CA) policy is sometimes necessary. However, doing so removes the protections of that policy for those specific items, potentially creating security vulnerabilities.

To maintain a strong security posture, every item excluded from a CA policy must be included in at least one other CA policy. This other policy serves as a "fallback," guaranteeing that no user or resource is left completely outside your conditional access controls.

## How to fix

Review policy exclusions. Create or confirm fallback policies exist to cover all excluded objects.