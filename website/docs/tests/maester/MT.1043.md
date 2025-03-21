---
title: MT.1043 - Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains
description: Checks if the Spam confidence level (SCL) is configured in mail transport rules with specific domains.
slug: /tests/MT.1043
sidebar_class_name: hidden
---

# Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains

## Description

> You should set Spam confidence level (SCL) in your Exchange Online mail transport rules with specific domains. Allow-listing domains in transport rules bypasses regular malware and phishing scanning, which can enable an attacker to launch attacks against your users from a safe haven domain.
> Note: In order to get a score for this security control, all the active transport rule that applies to specific domains must have a Spam Confidence Level (SCL) of 0 or higher.

## How to fix

> 1. Navigate to [Exchange Admin Center](https://admin.cloud.microsoft.com/exchange)
> 2. In the left navigation, go to **Mail Flow** and then select **Rules**.
> 3. For each rule that allows specific domains, set the spam confident level (SCL) to 0 or greater.
> 4. In "**Do the following**" section, select "**Modify the message properties**" > "**set the spam confidence level (SCL)**" and set the value to at least 0 (specifying the action for this domain, read more in the references attached below, some options may entirely block mail from this domain).

## Learn more
[Spam confidence level (SCL) in EOP](https://learn.microsoft.com/en-us/defender-office-365/anti-spam-spam-confidence-level-scl-about)