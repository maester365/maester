---
title: The end of code signing
description: An announcement that the Maester module code will no longer be signed.
slug: the-end-of-code-signing
authors: [fabian]
tags: [code-signing]
hide_table_of_contents: false
date: 2025-11-01
---

When we started with Maester, we were in the luxurious position to use a code signing certificate for all published versions. This, sadly, ends today.

<!-- truncate -->

## Code signing and PowerShell

Regardless if you publish a PowerShell module to the PowerShell gallery or just have a PowerShell script in your home folder, the code in those files, normally is just that, code. But if you have a code signing certificate from a trusted certification authority, you can use this to sign the PowerShell files, which allows anybody else to verify that nobody has tampered with the contents.

This concept is great in theory, but has a few downsides:

* Code Signing certificates are very expensive.
* With the recent changes to code signing certificates, they have to reside inside a HSM, adding operational cost.
* As an open source project you might sign code that is not yours.

The current code signing certificate that Fabian offered at the beginning still has a few months until it's no longer valid, but at the end of this period it won't be extended anymore. Therefore we had to make the decision if we want to sign Maester going forward. There are a few projects out there that offer code signing to open source tools for free, but there are a lot of requirements regarding external code sources that made this road unfeasible for us.

In the end, code signing a PowerShell module adds some value, but the cost outweighs the need, and we decided to stop now.

Starting from version **1.4.0** and any pre-release starting from **1.3.101**, the module will no longer be signed.

### Why should I care?

If you use Maester in a CI/CD pipeline with managed workers, nothing will noticeably change. The workers don't persist the module information after running, it and the next run will go through the module installation like always.

But if you have Maester installed on your own machine, PowerShell will throw the following error, calling out that the new version is no longer signed.

```powershell
Update-Module Maester -AllowPrerelease
```

![Install-Package: The version '1.3.105' of the module 'Maester' being installed is not catalog signed. Ensure that the version '1.3.105' of the module 'Maester' has the catalog file 'Maester.cat' and signed with the same publisher 'CN=Fabian Bader,
O=Fabian Bader, L=Hamburg, C=DE' as the previously-installed module 'Maester' with version '1.3.0' under the directory 'C:\Users\Fabian\Documents\PowerShell\Modules\Maester\1.3.0'. If you still want to install or update, use -SkipPublisherCheck parameter.](img/errormessage.png)

> Install-Package: The version '1.3.105' of the module 'Maester' being installed is not catalog signed. Ensure that the version '1.3.105' of the module 'Maester' has the catalog file 'Maester.cat' and signed with the same publisher 'CN=Fabian Bader, O=Fabian Bader, L=Hamburg, C=DE' as the previously-installed module 'Maester' with version '1.3.0' under the directory 'C:\Users\Fabian\Documents\PowerShell\Modules\Maester\1.3.0'. If you still want to install or update, use -SkipPublisherCheck parameter.

Sadly, the `-SkipPublisherCheck` switch is not available for the `Update-Module` cmdlet.

### Solution

The solution is to install the new version once with:

```powershell
Install-Module Maester -AllowPrerelease -Force -SkipPublisherCheck
```

We gladly welcome any [feedback](https://github.com/maester365/maester/discussions) or [suggestions for improvements](https://github.com/maester365/maester/issues). You can also join our community on [Discord](https://discord.gg/CQs76Wa9). Thank you!
