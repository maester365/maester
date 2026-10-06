---
title: 🧪 Updating tests
---

# Updating your Maester tests

The Maester team adds new tests over time. From Maester 3.0 the built-in tests ship inside the Maester module, so
**updating the module updates the tests**. There is nothing to copy into your tests folder.

### Step 1: Update the Maester module

Update the **Maester** PowerShell module to the latest version.

```powershell
Update-Module Maester -Force
```

Then close PowerShell and open a new session, so the new version is loaded:

```powershell
Import-Module Maester
```

### Step 2: Check what changed

`Get-MtTest` lists the tests of the version you have loaded, without connecting to a tenant:

```powershell
Get-MtTest | Measure-Object
(Get-Module Maester).Version
```

New tests run automatically. If you hold new tests back until you have reviewed them, use
`"DefaultAction": "Skip"` in your [run configuration](configuration/run-configuration.md#selection).

### Upgrading from Maester 2.x

In 2.x, `Install-MaesterTests` copied the tests into your folder and `Update-MaesterTests` replaced the copies.
In 3.0 those copies are no longer used: Maester recognises them, does not run them, and warns. Remove them once:

```powershell
cd maester-tests
Update-MaesterTests -WhatIf   # list what would be removed
Update-MaesterTests           # remove the copies (asks for confirmation; add -Force to skip it)
```

* Your custom tests in the `Custom` folder are never touched.
* A file that holds your own tests as well as copies of built-in tests is kept, with a warning.

Remove Maester 2.x from the machine too, so it cannot be loaded by accident:

```powershell
Uninstall-Module Maester -MaximumVersion 2.99.99 -AllVersions
```

See [Upgrading from 2.x](upgrading-from-2x.md) for everything else that changed.

:::note

If you are not seeing the latest tests, close and reopen your PowerShell session after **Step 1**
(`Update-Module`). A module that is already loaded cannot be replaced in a running session.

:::
