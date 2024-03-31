---
sidebar_position: 1
title: Introduction
---

# Quick Start

## What is Maester?

Maester is a PowerShell based test automation framework to help you monitor your Microsoft 365 security configuration.


- Install the **Maester** PowerShell module.
- Connect

```powershell
md maester-tests
cd maester-tests

Install-Module Maester -Scope CurrentUser

Install-MaesterTests .\tests

Connect-Maester

Invoke-Maester
```

FAQ

### Previously install 'Pester' version '3.4.0' conflicts with new module.

If you see the following error when installing Maester, it means that you have an older version of Pester installed.

```
A Microsoft-signed module named 'Pester' with version '3.4.0' that was previously installed conflicts with the new module 'Pester'
```

Run the following command to install the latest version of Pester and then retry installing Maester.

```powershell
Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
```



### Prerequisites

* Install git from [https://git-scm.com/](https://git-scm.com/)


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


