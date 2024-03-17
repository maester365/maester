---
title: User can joint the tenant by email validation (allowEmailVerifiedUsersToJoinOrganization)
slug: /tests/EIDSCA.authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization
sidebar_class_name: hidden
---

# User can joint the tenant by email validation

Controls whether users can join the tenant by email validation. To join, the user must have an email address in a domain which matches one of the verified domains in the tenant.

| | |
|-|-|
| **Name** | allowEmailVerifiedUsersToJoinOrganization |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | Medium |

## How to fix
| | |
|-|-|
| **Recommendation** | [Self-service sign up for email-verified users - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/enterprise-users/directory-self-service-signup) |
| **Configuration** | policies/authorizationPolicy |
| **Setting** | `allowEmailVerifiedUsersToJoinOrganization` |
| **Recommended Value** | 'false' |
| **Default Value** | true |
| **Graph API Docs** | [authorizationPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
      TA0001 - Initial Access - Initial Access
    (Mitigation)

    (Technique)

```
|Tactic|Technique|Mitigation|
|---|---|---|
|[TA0001 - Initial Access - Initial Access](https://attack.mitre.org/tactics/TA0001)|||

