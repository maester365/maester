---
title: MT.1042 - Restrict dial-in users from bypassing a meeting lobby
description: Checks if dial-in users are restricted from bypassing a meeting lobby
slug: /tests/MT.1042
sidebar_class_name: hidden
---

# Restrict dial-in users from bypassing a meeting lobby

## Description

> Dial-in users aren’t authenticated though the Teams app. Increase the security of your meetings by preventing these unknown users from bypassing the lobby and immediately joining the meeting.

## How to fix

> 1. Log into [Microsoft Teams Admin Center](https://aka.ms/teamsadmincenter)
> 2. In the left navigation, go to **Meetings** > **Meeting Policies**
> 3. Under **Manage Policies**, select a group/direct policy
> 4. Under the **Meeting join & lobby**, toggle "**Allow dial-in users to bypass the lobby**" to **Off**
> 5. You’ll need to change this setting for each group/direct policy
