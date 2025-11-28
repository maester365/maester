---
title: Advanced guide
sidebar_position: 3
---

## Overview

In this guide we will cover advanced concepts for writing custom tests with Maester.

## Invoke-MtGraphRequest

Maester provides a function called `Invoke-MtGraphRequest` that allows you to make direct calls to the Microsoft Graph API. This is an enhanced version of the `Invoke-MgGraphRequest` function that has been optimized for Maester's use case to query Microsoft Graph data.

Here's an example of how you can use `Invoke-MtGraphRequest` to get all the users in your tenant.

```powershell
$users = Invoke-MtGraphRequest -RelativeUri "users"
```

### Caching: Invoke-MtGraphRequest's secret sauce

`Invoke-MtGraphRequest` has built-in caching to reduce the number of calls to the Microsoft Graph API when running Maester tests.

This way you can write tests that call into any Graph API and if that data has already been fetched in the Maester run, the cached data will be used instead of querying Microsoft Graph. This is one of the reasons we can run multiple tests in a very performant way.

The cache is reset when you run Invoke-Maester to ensure you always have the latest data.

If your tests use Graph cmdlets like `Get-MgUser`, they will not benefit from this caching mechanism and will make a call to the Graph API every time they are run.

### Other key features of `Invoke-MtGraphRequest`:

In addition to caching, `Invoke-MtGraphRequest` has other key features that make it very easy to write tests that query data.

- Automatically handles pagination and get's all of the users by default (you don't need to specific -All)
- Includes **ConsistencyLevel** by default to all the calls. This works for Maester's read-only use case and allows you to use any of the advanced query filter options without worrying about the consistency flag.
- Provides automatic support for batching by passing in an array of Object IDs to the `-UniqueId` parameter.
- Named parameters for `Select`, `Filter` and `QueryParameters` to make it easier to write complex queries.

Here are a few examples.

#### Get selected list of users users with specific properties

Use the `UniqueId` parameter to get specific users by their Object ID and select only the properties you need.

The $usersIds array can have one or hundreds of object IDs. Invoke-MtGraphRequest will optimize the calls by batching and paging through the results.

```powershell
$userIds = @($globalAdministrators.Id)

Write-Verbose "Requesting users onPremisesSyncEnabled property"
$users = Invoke-MtGraphRequest -RelativeUri "users" -UniqueId $userIds -Select id, displayName, onPremisesSyncEnabled

```

#### Specify api version, filters, query parameters with expand

This example shows how you can splat the code to make it easier to read when you have a complex query.

```powershell
$policySplat = @{
    ApiVersion      = "beta"
    RelativeUri     = "policies/roleManagementPolicyAssignments"
    Filter          = "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$($globalAdministratorsRole.id)'"
    QueryParameters = @{
        expand = "policy(expand=rules)"
    }
}
$policy = Invoke-MtGraphRequest @policySplat
```

To learn more see [Invoke-MtGraphRequest](https://github.com/maester365/maester/blob/main/powershell/public/Invoke-MtGraphRequest.ps1).

## Splitting tests into multiple files

As you write more tests you might find it helpful to split out the markdown part of the tests into a separate file. This helps reduce clutter in the test code and also allows content writers to independently edit the markdown files. Almost all the out of the box Maester tests use this approach of splitting out the markdown content for the test.

Here's an example of how you can split out the markdown content into a separate file.

This custom test checks if there are any users without a manager assigned.

### Step 1: Create the tests file in the `Custom` folder

Create a new file in the `Custom` folder with the `.Tests.ps1` suffix.

#### ContosoUsers.Tests.ps1

```powershell
BeforeAll {
    . $PSScriptRoot/Test-ContosoUsersMissingManagers.ps1
}
Describe "Contoso" -Tag "Entra", "CustomTests", "Users" {
    It "CTS.1001: Manager Attribute - All users should have a manager attribute set" {
        $result = Test-ContosoUsersMissingManagers
        $result | Should -Be $true -Because "All users should have a manager assigned."
    }
}
```

### Step 2: Create test functions file

Create the test file in the `Custom` folder that was referred to in the `BeforeAll` block in the previous step.

#### Test-ContosoUsersMissingManagers.ps1

```powershell
function Test-ContosoUsersMissingManagers {
    $result = $true

    try {
        # Retrieve all users from Microsoft Graph
        $users = Invoke-MtGraphRequest -RelativeUri "users" -Filter "userType eq 'Member'"

        # Initialize an array to track users without a manager
        $usersWithoutManager = @()

        # Loop through each user and ensure they have a manager assigned
        foreach ($user in $users) {
            if($user.jobTitle -eq "CEO" -or $user.displayName -eq "On-Premises Directory Synchronization Service Account" ) {
            continue
}

            # Fetch the manager for the current user
            $manager = Get-MgUserManager -UserId $user.Id -ErrorAction SilentlyContinue

            if ([string]::IsNullOrEmpty($manager)) {
                $result = $false
                $usersWithoutManager += $user
            }
        }

        if ($result) {
            $TestResults = "Well done! There were no users with out managers assigned."
        } else {
            $TestResults += "No managers are assigned for the following users.`n%TestResult%"
        }

        Add-MtTestResultDetail -Result $TestResults -GraphObjects $usersWithoutManager -GraphObjectType Users
    } catch {
        $result = $false
        Write-Error $_.Exception.Message
    }

    return $result
}
```

:::note
To use the markdown content from the file, **do not** include the `-Description` parameter when calling `Add-MtTestResultDetail`.
:::

### Step 3: Create the markdown file

Create a markdown file in the `Custom` folder **with the same name as the test file** but with the `.md` extension.

#### Test-ContosoUsersMissingManagers.md

```md
This test checks if there are any users without a manager assigned.

Contoso's company policy requires that all users have a manager assigned to them. This is important for accountability and delegation of responsibilities.

**To remediate this issue:**

- Identify the users without a manager.
- Raise a ticket in Service Now using [Form: Manager Missing - HR Ticket](https://contoso.service-now.com/managermissing) to request the manager assignment for the users identified in this test.
  - 🔺 If this is not actioned in three days, escalate to the HR manager.

**Learn more:**

- [Manager Missing - HR Ticket](https://contoso.service-now.com/managermissing)
- [HR Escalation Process](https://contoso.service-now.com/hrescalation)

<!--- Results --->

%TestResult%

```

### Step 4: Run the test

Running the test should now show the markdown content in the test results.

![ContosoUsersMissingManagers](img/advanced-concepts-split-markdown.png)