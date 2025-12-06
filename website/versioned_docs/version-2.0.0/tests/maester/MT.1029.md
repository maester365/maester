---
title: MT.1029 - Stale accounts are not assigned to privileged roles
description: Checks if PIM alert for users with stale sign-in exists
slug: /tests/MT.1029
sidebar_class_name: hidden
---

# Stale accounts are not assigned to privileged roles

## Description

This alert is for accounts in a privileged role that haven't signed in during the past n days, where n is many days that is configurable between 1-365 days. These accounts might be service or shared accounts that aren't being maintained and are vulnerable to attackers. Default configuration is set to 30 days.

_Note: By default, the check excludes emergency access (Break Glass) accounts which has been identified by Maester._

## How to fix

Review the users in the list and remove them from privileged roles that they don't need.
Notes in the Maester test results provide direct link to the alert page with details to identify and how to address the recommendations.

## Learn more

- [Details of PIM Alert "Potential stale accounts in a privileged role"](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-how-to-configure-security-alerts#potential-stale-accounts-in-a-privileged-role)
