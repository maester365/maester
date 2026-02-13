Creation of Team Foundation Version Control (TFVC) repositories SHOULD BE disabled.

Rationale: Over the past several years, we added no new features to Team Foundation Version Control (TFVC). Git is the preferred version control system in Azure Repos. Furthermore, all the improvements we made in the past few years in terms of security, performance, and accessibility were only made to Git repositories. 

#### Remediation action:
Enable the policy to disable the creation of TFVC repositories.
1. Sign in to your organization
2. Choose Organization settings.
3. Under the Repos section choose Repositories.
4. In the All Repositories Settings section, toggle on "Disable creation of TFVC repositories".

**Results:**
Disable creation of TFVC repositories. You can still see and work on TFVC repositories created before.

#### Related links

* [Learn - Removal of RFVC in new projects](https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2024/no-tfvc-in-new-projects)
