---
title: MT.1036 - All excluded objects should have a fallback include in another policy.
description: Checks for gaps in conditional access policies, by looking for excluded objects which are not specifically inlcuded in another conditional access policy. This way we try to spot possibly overlooked exclusions which do not have a fallback.
slug: /tests/MT.1036
sidebar_class_name: hidden
---

# All excluded objects should have a fallback include in another policy

## Description

When exlcuding objects from consitional access policies, you are basically creating gaps into your protection mechanisms. To make sure these gaps are not left open, the excluded objects should be included in another 'fallback' policy. By doing this, you make sure al objects are protected and no gaps exists.

## How to fix

Review the excluded objects and their related policies and try to create a fallback policy for them.