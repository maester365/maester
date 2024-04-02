---
sidebar_position: 1
title: Introduction
---

# Quick Start

## What is Maester?

Maester is a PowerShell based test automation framework to help you monitor your Microsoft 365 security configuration.


- Install the **Maester** PowerShell module, Pester and the out of the box tests.

```powershell
Install-Module Pester -SkipPublisherCheck -Force -Scope CurrentUser
Install-Module Maester -Scope CurrentUser

md maester-tests
cd maester-tests
Install-MaesterTests .\tests
```

- Sign into your Microsoft 365 tenant and run the tests.

```powershell
Connect-Maester
Invoke-Maester
```




## Reporting Test Results

[TBD]

### Daily Mail alerts

[TBD]

## Writing Custom Tests

While you can use the pre-defined tests that we've created for you, you can also write your own custom tests.

Here's how you can do this.
[TBD]

## Setting up daily automated tests

Follow the guides here to setup daily automated tests.

### GitHub Actions

### Azure DevOps


