---
title: Maester adds ORCA tests
description: Maester now includes the valuable tests from the ORCA project
slug: maester-with-orca
authors: mike
tags: [release,ORCA,Tests]
hide_table_of_contents: false
date: 2025-05-12
image: ./img/orca.png
#draft: true # Draft
#unlisted: true # https://github.com/facebook/docusaurus/pull/1396#issuecomment-487561180
---

The Maester module can now dynamically build the necessary files for testing and reporting on all the [Office 365 Recommended Configuration Analyzer (ORCA)](https://github.com/cammurray/orca) controls. Providing users with a single report covering many controls that existed before Maester and which are still valuable. 🚀

<!-- truncate -->

## What is ORCA?

[Cam Murray](https://github.com/cammurray) created the [Office 365 Recommended Configuration Analyzer (ORCA)](https://github.com/cammurray/orca) PowerShell module to help align tenant configuration with Microsoft's recommended configurations. Many of these settings are available in the [configuration analyzer](https://learn.microsoft.com/en-us/defender-office-365/configuration-analyzer-for-security-policies) today, but ORCA provided these insights earlier and often in a more concise approach. Building these configuration items as tests in Maester provided an awesome way to build on the core ORCA module value and bring even more context into the configuration state of a tenant.

## How to build?

The ORCA module utilizes user defined types with [enumerations](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_enum) and [classes](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes) heavily. This is the best approach for an individual module and helps produce well-typed and structured code bases. It also can be challenging when trying to merge code bases dynamically as those types within the module need to exist outside the module.

> [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) have their own issues too so definitely avoid those unless the challenges are worth it.

To handle this, PowerShell has this awesome feature called the [abstract syntax tree (AST)](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.ast). This feature allows you to parse PowerShell files and interface with them as structured objects. Using the AST the Maester team was able to build a [script](https://github.com/maester365/maester/blob/main/build/orca/Update-OrcaTests.ps1) to parse the ORCA code base and dynamically build the necessary functions, tests, and report details for incorporating with the Maester module.

> Similarly and even more elegantly the EIDSCA team was able to incorporate their module as [well](https://github.com/maester365/maester/blob/main/build/eidsca/Update-EidscaTests.ps1).

## Results

With this build script, the Maester module can now dynamically build the necessary files for testing and reporting on all the ORCA controls. Providing users with a single report covering many controls that existed before Maester and which are still valuable.

![image](https://github.com/user-attachments/assets/f2a9a5bd-c3e3-4adc-96d5-059db1247d7a)

## Acknowledgements

Huge shoutout to the Maester team for all of their awesome contributions in this substantial addition, including:
* [Thomas S. Schmidt](https://github.com/tdcthosc)
* [Cameron Moore](https://github.com/moorereason)
* [Cam Murray](https://github.com/cammurray)

## Contributor

- [Mike Soule](/blog/authors/mike)