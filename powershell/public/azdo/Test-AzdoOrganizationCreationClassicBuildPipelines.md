Creating classic build pipelines SHOULD BE disabled.

Rationale: YAML pipelines offer the best security for your Azure Pipelines. In contrast to classic build and release pipelines.

#### Remediation action:
Enable the policy to disable creation of classic build pipelines.
1. Sign in to your organization
2. Choose Organization settings.
3. Under the Pipelines section choose Settings.
4. In the General section, toggle on Disable creation of classic build pipelines.

**Results:**
*How the feature works*
If you turned on the toggle to Disable creation of classic build and classic release pipelines, then no classic build pipeline, classic release pipeline, task groups, and deployment groups can be created.

The user interface will not show the Releases, Task groups, and Deployment groups left-side menu items if you have none of them.

*Existing classic pipelines*
If you have classic build pipelines, classic release pipelines, task groups, or deployment groups, you’ll still be able to edit and run them. The Pipelines left-side menu will continue to show the corresponding menu items. However, the buttons to create new ones will be disabled.

#### Related links

* [Devblog - Disable creation of classic pipelines](https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/)
