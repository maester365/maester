---
title: MT.1049 - Sign-in risk and user risk conditions should be configured in separate Conditional Access policies
description: Checks for common misconfigurations in Conditional Access; both user risk and sign-in risk are configured in one policy.
slug: /tests/MT.1049
sidebar_class_name: hidden
---

# Sign-in risk and user risk conditions should be configured in separate Conditional Access policies

## Description

There are two types of risk policies in Microsoft Entra Conditional Access you can set up. You can use these policies to automate the response to risks allowing users to self-remediate when sign-in risk or user risk is detected. Sign-in risk and user risk should not be configured in a single policy, but instead be separated as Conditional Access policies will only be applied if ALL conditions match. 

## Rationale

If you configure both conditions in one policy, it will only block access if both types of risk are detected. This means if only one type of risk is present (like user risk only), the sign-in will be not be blocked or interrupted. This could lead to a security gap, as some risky actions might slip by.

## How to fix

Configure separate Conditional Access policies for sign-in risk and user risk

## Learn more
  - [Microsoft Learn | Configure and enable risk policies](https://learn.microsoft.com/en-us/entra/id-protection/howto-identity-protection-configure-risk-policies)
  - [janbakker.tech | Conditional Access risk policies. Don’t get fooled!](https://janbakker.tech/conditional-access-risk-policies-dont-get-fooled/)
