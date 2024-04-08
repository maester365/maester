---
title: Installation guide
---

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

- Monitoring with Maester
  - [Set up Maester on GitHub](/docs/monitoring/github)
  - [Set up Maester on Azure DevOps](/docs/monitoring/azure-devops)
  - [Set up Maester email alerts](/docs/monitoring/email)
- [Writing Custom Tests](/docs/writing-tests)
