---
title: MT.1036 - All excluded objects should have a fallback include in another policy.
description: Checks if all objects used in policy exclusions can be found as included into another policy
slug: /tests/MT.1036
sidebar_class_name: hidden
---

# All excluded objects should have a fallback include in another policy

## Description

When exlcuding objects from consitional access policies, you are basically creating gaps into your protection mechanisms. To make sure these gaps are not left open, the excluded objects should be included in another 'fallback' policy. By doing this, you make sure al objects are protected and no gaps exists.

## How to fix

Review the excluded objects and their related policies and try to create a fallback policy for them.