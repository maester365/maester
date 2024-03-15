---
sidebar_position: 5
title: Contributing
---

# Contributing

## Developer Guide

### Simple debugging

- Set a breakpoint anywhere in the code and hit F5
- The launch.json has been configured to re-load the module and run Invoke-Maester.ps1
- Change the Tag filter in Invoke-Maester.ps1 to run just the tests file you need.

### Manual editing

- Load the PowerShell module. This needs to be done anytime you make changes to the code in src.
  - `Import-Module ./src/Maester.psd1 -Force`
- Run the tests
  - `./tests/Invoke-Maester.ps1`
