---
title: MT.1040 - Ensure additional storage providers are restricted in Outlook on the web
description: Checks if additional storage providers are restricted in Outlook on the web
slug: /tests/MT.1040
sidebar_class_name: hidden
---

# Ensure additional storage providers are restricted in Outlook on the web

## Description

> This setting allows users to open certain external files while working in Outlook on the
web. If allowed, keep in mind that Microsoft doesn't control the use terms or privacy
policies of those third-party services. Ensure AdditionalStorageProvidersAvailable is restricted.

> Rationale: By default additional storage providers are allowed in Office on the Web (such as Box,
Dropbox, Facebook, Google Drive, OneDrive Personal, etc.). This could lead to
information leakage and additional risk of infection from organizational non-trusted
storage providers. Restricting this will inherently reduce risk as it will narrow
opportunities for infection and data leakage.

## How to fix

> 1. Connect to Exchange Online using `Connect-ExchangeOnline`.
> 2. Run the following PowerShell command:
> `Set-OwaMailboxPolicy -Identity OwaMailboxPolicy-Default -AdditionalStorageProvidersAvailable $false`
> 3. Run the following Powershell command to verify that the value is now False:
> `Get-OwaMailboxPolicy | Format-Table Name, AdditionalStorageProvidersAvailable`
