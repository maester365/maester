---
title: MT.1037 - Only users with Presenter role are allowed to present in Teams meetings
description: Checks that only users with Presenter role are allowed to present in Teams meetings
slug: /tests/MT.1037
sidebar_class_name: hidden
---

# Only users with Presenter role are allowed to present in Teams meetings

> Secure Score Name: Configure which users are allowed to present in Teams meetings

## Description

> Only allow users with presenter rights to share content during meetings. Restricting who can present limits meeting disruptions and reduces the risk of unwanted or inappropriate content being shared.

## How to fix

> 1. Log into [Microsoft Teams admin center](https://aka.ms/teamsadmincenter)
> 2. In the left navigation, go to **Meetings** > **Meeting Policies**
> 3. Under **Manage Policies**, select a group/direct policy
> 4. Under **Content sharing** section, switch **Who can present** to "**Only organizers and co-organizers**"
> 5. You’ll need to change this setting for each group/direct policy