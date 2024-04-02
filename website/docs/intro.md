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

## Next Steps

- [Writing Custom Tests](/docs/writing-tests)
- Monitoring with Maester
  - [Set up Maester on GitHub](/docs/monitoring/github)
  - [Set up Maester on Azure DevOps](/docs/monitoring/azure-devops)
  - [Set up Maester email alerts](/docs/monitoring/email)

