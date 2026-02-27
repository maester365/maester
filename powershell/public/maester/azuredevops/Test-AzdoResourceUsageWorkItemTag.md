Azure DevOps supports up to 150,000 tag definitions per organization or collection.

Rationale: Tags are useful for categorizing and querying work items, but an excessive number of unique tags can degrade performance and make management difficult. Hitting the limit may prevent users from creating new tags and could cause UI slowdowns.

#### Remediation action:
Regularly review your tag inventory and delete unused or obsolete tags. Consider standardizing on a controlled vocabulary or using area/iteration paths when appropriate.

**Results:**
Keeping the tag count below the limit ensures responsive work item searches and avoids hitting a hard cap that would block new tags.

#### Related links

* [Learn - Work tracking, process, and project limits](https://learn.microsoft.com/en-us/azure/devops/organizations/settings/work/object-limits?view=azure-devops)
