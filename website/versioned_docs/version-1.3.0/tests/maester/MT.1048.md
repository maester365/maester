---
title: MT.1048 - Limit external participants from having control in a Teams meeting
description: Checks if external participants can give or request control in a Teams meeting
slug: /tests/MT.1048
sidebar_class_name: hidden
---

# Limit external participants from having control in a Teams meeting

## Description

> External participants are users that are outside your organization. Limiting their permission to share content, add new users, and more protects your organization’s information from data leaks, inappropriate content being shared, or malicious actors joining the meeting.

## How to fix

> 1. Log into [Microsoft Teams admin center](https:/aka.ms/teamsadmincenter)
> 2. In the left navigation, go to **Meetings** > **Meeting Policies**
> 3. Under **Manage Policies**, select a group/direct policy
> 4. Under the **Content Sharing** section, switch "**External participants can give or request control**" to **Off**
> 5. You’ll need to change this setting for each group/direct policy
