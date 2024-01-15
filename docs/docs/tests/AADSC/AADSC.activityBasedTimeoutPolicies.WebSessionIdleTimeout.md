---
title: AADSC.activityBasedTimeoutPolicies.WebSessionIdleTimeout
description: WebSessionIdleTimeout - Enable directory level idle timeout
---

# Enable directory level idle timeout

Inactivity timeout is being enforced by this setting. You will be signed out after the configured time of inactivity.

| | |
|-|-|
| **Name** | WebSessionIdleTimeout |
| **Control** | Default Activity Timeout |
| **Description** | Control the idle timeout for web sessions for applications that support activity-based timeout functionality |
| **Severity** | Informational |



## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/activityBasedTimeoutPolicies |
| **Setting** | `definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [activityBasedTimeoutPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/activitybasedtimeoutpolicy) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/activityBasedTimeoutPolicies&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#settings) | 

