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

Today we are happy to announce some changes in Maester that will make it easier to use tags to assess your M365 environment specific types of tests. 🏷️

<!-- truncate -->

## A Review of How Tags are Used

When you run Maester with no tag-related parameters, it automatically includes all available tests *except* tests that rely on features that are still in preview and tests that can take a very long time in large environments. The goal with this default behavior is to quickly get results with minimum learning curve.

### Run All Default Tests

```powershell
Invoke-Maester -Path './maester-tests'
```

Runs all default the tests in the folder `./maester-tests` (excludes long running and preview, as noted above) and generates a report of the results in the default `./test-results` folder.

### Run Tests with Specific Tags

You can use the **Tag** parameter to target tests with specific tags. For example:

```powershell
Invoke-Maester -Tag 'CA', 'MFA'
```

Only run tests with the 'CA' or 'MFA' tags.

### Exclude Tests with Specific Tags

```powershell
Invoke-Maester -ExcludeTag 'App', 'Azure'
```

Run all tests, excluding any tagged with 'App' or 'Azure'. By default, tests that can take a very long time in large environments and tests that rely on features that are still in preview are still excluded as well.

## What has changed?

### New Parameters for Deprecated Tags

`Invoke-Maester` now has two new parameters:

- **IncludeLongRunning** - Include tests that may take a long time in tenants that have a large number of user, group, or application objects.
- **IncludePreview** - Include tests that rely on functionality that is still in preview status. These might be tests that are based on new techniques that are still being validated or are using the beta Graph API.

:::info

We can use these two options along with (inclusive of) any other combination of tags or excluded tags. However, tag exclusions will always override inclusions.

:::

These two switch parameters have been introduced so we can begin the removal of two tags that were ambiguous.

| Original Tag | Original Intent | New Parameter |
| --- | --- | --- |
| All | Include "all" tests, including those still in preview. | `-IncludePreview` |
| Full | Include "full" testing, including those that may take a long time in large environments. | `-IncludeLongRunning` |

As you can imagine, the original naming lead to many people adding the `All` and `Full` tags to their test definitions with the goal of being included. Now, running Maester with every available test can be accomplished as shown below. Note that you can still combine these parameters with other options:

```powershell
Invoke-Maester -Path './maester-tests' -IncludeLongRunning -IncludePreview
```

Runs all tests in the path  -Path `./maester-tests` including preview and long running tests.

### What is Next?

:::warning

Potential breaking changes for automated Maester jobs.

:::

We have done our best to deprecate the `All` and `Full` tags gracefully. They have been removed from all tests, but the `Invoke-Maester` function has been updated to handle their use for the time being. However, this code may be removed in the future to keep Maester streamlined and easy to maintain. We support this

- The `-IncludeLongRunning` switch is automatically enabled when the **Full** tag is included.
- The `-IncludePreview` switch is automatically enabled when the **All** tag is included.

If these tags are used, you will now see a warning in the output:

**If you have implemented Maester through a scheduled task, workflow, or pipeline; please be sure to review your implementation to replace any use of the `All` and `Full` tags accordingly.**

### Bonus: A new tag and test inventory function

Describe the new function...

### Documentation

Add links to relevant documentation here...
