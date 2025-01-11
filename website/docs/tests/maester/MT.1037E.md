---
title: MT.1037 - Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains
description: TBD (Exchange)
slug: /tests/MT.1037
sidebar_class_name: hidden
---

# Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains

## Description

> You should set Spam confidence level (SCL) in your Exchange Online mail transport rules with specific domains. Allow-listing domains in transport rules bypasses regular malware and phishing scanning, which can enable an attacker to launch attacks against your users from a safe haven domain.
> Note: In order to get a score for this security control, all the active transport rule that applies to specific domains must have a Spam Confidence Level (SCL) of 0 or higher.

## How to fix

> 1. >Navigate to Exchange admin center https://admin.exchange.microsoft.com.
> 2. Click to expand Mail Flow and then select Rules.
> 3. For each rule that allows specific domains, set the spam confident level (SCL) to 0 or greater.
>
>> In "Do the following" section, select "Modify the message properties" and "set the spam confidence level (SCL)" and set to at least 0 (specifying the action for this domain, read more in the references attached below, some options may entirely block mail from this domain).
