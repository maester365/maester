---
title: MT.1039 - Ensure MailTips are enabled for end users
description: Check if MailTips are enabled for end users
slug: /tests/MT.1039
sidebar_class_name: hidden
---

# Ensure MailTips are enabled for end users

## Description

> MailTips assist end users with identifying strange patterns to emails they send.

## How to fix

> 1. Run Microsoft Exchange Online PowerShell Module
> 2. Connect using "Connect-ExchangeOnline"
> 3. Run the following PowerShell command:
> `Set-OrganizationConfig -MailTipsAllTipsEnabled $true -MailTipsExternalRecipientsTipsEnabled $true -MailTipsGroupMetricsEnabled $true -MailTipsLargeAudienceThreshold '25'`
