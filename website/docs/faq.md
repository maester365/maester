---
sidebar_position: 6
title: ❓ FAQ
---

## Previously installed 'Pester' version '3.4.0' conflicts with new module

If you see the following error when installing Maester, it means that you have an older version of Pester installed.

**A Microsoft-signed module named 'Pester' with version '3.4.0' that was previously installed conflicts with the new module 'Pester'**

Run the following command to install the latest version of Pester and then retry installing Maester.

```powershell
Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
```

To learn more or if you run into Pester installation issues see [Pester Installation and Update](https://pester.dev/docs/introduction/installation)

