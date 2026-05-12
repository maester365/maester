---
title: MT.Zta.1110 - iOS App Protection Policy covers unmanaged devices and is assigned to user/group
description: "When ZTA ['24543'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24543.md) (compliance policies protect iOS) or ['24548'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24548.md)..."
slug: /tests/MT.Zta.1110
sidebar_class_name: hidden
---

# iOS App Protection Policy covers unmanaged devices and is assigned to user/group

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.DeviceCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.DeviceCompensation.Tests.ps1) |

## Description

When ZTA [`24543`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24543.md) (compliance policies protect iOS) or [`24548`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24548.md) (data on iOS protected by APP) is Failed, verifies that an Intune App Protection Policy (APP / MAM-WE) for iOS:
1. Targets `unmanagedAndManaged` device states (not just `managedDevices`).
2. Is enabled (not in draft).
3. Has at least one **`groupAssignmentTarget`** assignment — i.e. the policy is assigned to a real user/security group, NOT just the `allLicensedUsersAssignmentTarget` placeholder which Intune injects by default but which doesn't surface in the operator's assigned-policy list and is easy to leave un-assigned in practice.
## How to fix

1. Intune → Apps → App protection policies → iOS/iPadOS → either create or edit the policy.
2. Set **Target apps** to all Microsoft 365 apps (or your scoped list).
3. Under **Targeted app management level**, choose **Unmanaged AND Managed** (or **All app types**).
4. Under **Assignments**, assign to a real group (e.g., "All employees" security group) — not the empty default.
5. Save and verify rollout via Intune → Apps → Monitor.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)