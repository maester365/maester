---
id: overview
title: CISA Exchange Online Controls
sidebar_label: Exchange Online
description: Implementation of CISA Exchange Online Controls
---

```mdx-code-block

# CISA Entra Controls

## Overview

The tests in this section verifies that a Microsoft 365 tenant’s configuration conforms to the policies described in the Secure Cloud Business Applications ([SCuBA](https://cisa.gov/scuba)) Security Configuration Baseline [documents](https://github.com/cisagov/ScubaGear/blob/main/baselines/README.md).

## ⚠️ Additional Modules

The CISA controls include tests that require access to additional API endpoints not currently available through the Microsoft Graph API.

The [`Connect-Maester`](../../commands/Connect-Maester) cmdlet supports connecting to multiple modules. Please connect to ExchangeOnline as shown below or manually create these connections for the cmdlets to function.

~~~
Connect-Maester -Service ExchangeOnline
~~~

## Tests

* Test-MtCisaAutoExternalForwarding - [MS.EXO.1.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo11v1)


```
