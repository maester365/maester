---
title: MT.1038 - Conditional Access policies should not include or exclude deleted groups.
description: This test checks if there are any Conditional Access policies that target deleted security groups.
slug: /tests/MT.1038
sidebar_class_name: hidden
---

# Conditional Access policies should not include or exclude deleted groups

## Description

This test checks if there are any Conditional Access policies that target deleted security groups.

This usually happens when a group is deleted but is still referenced in a Conditional Access policy.

Deleted groups in your policy can lead to unexpected gaps. This may result in Conditional Access policies not being applied to the users you intended or the policy not being applied at all.

## How to fix

* Open the impacted Conditional access policy.
* If the group is no longer needed, click Save to remove the referenced group from the policy.
* If the group is still needed, update the policy to target a valid group.