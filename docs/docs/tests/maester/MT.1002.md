---
title: MT.1002 - Enforce credential configurations on apps and service principals
description: By default Microsoft Entra ID allows service principals and applications to be configured with weak credentials.
slug: /tests/MT.1002
sidebar_class_name: hidden
---

# Enforce credential configurations on apps and service principals

## Description

By default Microsoft Entra ID allows service principals and applications to be configured with weak credentials.

This can include

- client secrets instead of certificates
- secrets and certificates with long expiry (e.g. 10 year)

## How to fix

Using shorter expiry periods and certificates instead of secrets can help reduce the risk of credentials being compromised and used by an attacker.

The sample policy below can be used to enforce credential configurations on apps and service principals.

```powershell
Import-Module Microsoft.Graph.Identity.SignIns

$params = @{
isEnabled = $true
applicationRestrictions = @{
    passwordCredentials = @(
    @{
        restrictionType = "passwordAddition"
        maxLifetime = $null
        restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2021-01-01T10:37:00Z")
    }
    @{
        restrictionType = "passwordLifetime"
        maxLifetime = "P365D"
        restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2017-01-01T10:37:00Z")
    }
    @{
        restrictionType = "symmetricKeyAddition"
        maxLifetime = $null
        restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2021-01-01T10:37:00Z")
    }
    @{
        restrictionType = "customPasswordAddition"
        maxLifetime = $null
        restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2015-01-01T10:37:00Z")
    }
    @{
        restrictionType = "symmetricKeyLifetime"
        maxLifetime = "P365D"
        restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2015-01-01T10:37:00Z")
    }
    )
    keyCredentials = @(
    @{
        restrictionType = "asymmetricKeyLifetime"
        maxLifetime = "P365D"
        restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2015-01-01T10:37:00Z")
    }
    )
}
}

Update-MgPolicyDefaultAppManagementPolicy -BodyParameter $params
```

## Learn more

- [Tenant App Management Policy - Microsoft Graph Reference](https://learn.microsoft.com/graph/api/resources/tenantappmanagementpolicy?view=graph-rest-1.0)
