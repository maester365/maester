---
title: What's New with Maester Tags
description: An announcement about new and improved tags that replace current ones, and a new function to get an inventory of tests per tag.
slug: whats-new-with-maester-tags
authors: [samerde]
tags: [tags,maester-v2]
hide_table_of_contents: false
image: ./img/________________.png
date: 2025-10-15
---

Tags are used to identify groups of tests and either include them or exclude them when running Maester. Today we are pleased to announce changes to some tags that will make it easier to get your desired results. 🏷️

<!-- truncate -->

## A review of how tags are used

When you run Maester with no tag-related parameters, it automatically includes all tests *except* tests that can take a very long time in large environments and tests that rely on features that are still in preview. You can also use parameters with `Invoke-Maester` to target tests with specific tags. For example:

### Run default tests

```powershell
Invoke-Maester ./maester-tests
```

Runs all the tests in the folder `./tests/Maester` (except for those tagged as LongRunning and Preview) and generates a report of the results in the default `./test-results` folder.

### Run specific tests with tags

```powershell
Invoke-Maester -Tag 'CA', 'MFA'
```

Only run tests with the 'CA' or 'MFA' tags.

### Exclude specific tests with tags

```powershell
Invoke-Maester -ExcludeTag 'App', 'Azure'
```

Run all tests, excluding any tagged with 'App' or 'Azure'. By default, tests that can take a very long time in large environments and tests that rely on features that are still in preview are still excluded as well.

### What has changed?

#### New parameters

`Invoke-Maester` now has two new parameters:

- **IncludeLongRunning** - Include tests that may take a long time in tenants that have a large number of user, group, or application objects.
- **IncludePreview** - Include tests that rely on functionality that is still in preview status. These might be tests that are based on new techniques that are still being validated or are using the beta Graph API.

#### Deprecated tags

These two new switch parameters have been introduced so we can begin the removal of two tags that were too ambiguous.

| Original Tag | Original Intent | New Parameter |
| --- | --- | --- |
| All | Include tests still in preview. | `-IncludePreview` |
| Full | Include tests that may take a long time in large environments. | `-IncludeLongRunning` |

As you can imagine, the original naming lead to many people adding the `All` and `Full` tags to their test definitions to simply be included. Now, running Maester will *all* tests can be accomplished as follows:

```powershell
Invoke-Maester -IncludeLongRunning -IncludePreview
```

### What is next?

:::warning

Potential breaking changes for automated Maester jobs.

:::

We have done our best to deprecate the `All` and `Full` tags gracefully. They have been removed from all tests, but the `Invoke-Maester` function has been updated to enable the `-IncludeLongRunning` switch when the `Full` tag is included or the `IncludePreview` switch when the `All` tag is included. In the future, this code may be removed to keep Maester streamlined and easy to maintain.

If you have implemented Maester through a scheduled task, workflow, or pipeline; please be sure to review your implementation to replace any use of the `All` and `Full` tags accordingly.

### Bonus: A new tag and test inventory function

Describe the new function...

### Documentation

Add links to relevant documentation here...
