---
title: MT.Zta.1111 - Android App Protection Policy covers unmanaged devices and is assigned to user/group
description: "Android counterpart of MT.Zta.1110. Triggered when ZTA ['24547'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24547.md) or ['24545'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessme..."
slug: /tests/MT.Zta.1111
sidebar_class_name: hidden
---

# Android App Protection Policy covers unmanaged devices and is assigned to user/group

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.DeviceCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.DeviceCompensation.Tests.ps1) |

## Description

Android counterpart of MT.Zta.1110. Triggered when ZTA [`24547`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24547.md) or [`24545`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24545.md) Failed. Verifies an Android APP exists with `targetedAppManagementLevels` covering unmanaged devices AND `assignments[].target` is a real groupAssignmentTarget (not the all-users placeholder).
## How to fix

1. Intune → Apps → App protection policies → Android → create / edit.
2. Set targeted app management level to include unmanaged scope.
3. Assign to a real security group.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)