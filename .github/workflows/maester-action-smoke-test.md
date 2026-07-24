# Demo tenant Invoke-Maester smoke test

`maester-action-smoke-test.yaml` exercises the published standard
`maester365/maester-action` on Linux, Windows, and macOS against a real
Microsoft 365 demo tenant. The same workflow supports two run types:

- **Quick** runs only the fast, platform-neutral Graph check `MT.1068`.
- **Full** runs all public Graph checks. Exchange, Teams, private, preview, and
  long-running tests remain disabled.

Each operating system's self-contained HTML report is written directly to the
private `maester365/maester-smoke-reports` repository for core-maintainer
review.

The gate intentionally accepts either `Passed` or `Failed` test results because
the demo tenant's security posture is not a release gate. Authentication,
Microsoft Graph, action, result-integrity, tenant, or runner errors fail the
workflow. The full run also accepts intentionally skipped tests but requires at
least one public Graph check to complete.

## Protected environment configuration

In `maester365/maester`, create a GitHub Actions environment named exactly
`maester-smoke-test`. Configure it before adding credentials:

1. Do not configure required reviewers. Approved-pull-request quick runs and
   every full run after a merge to `main` must start automatically.
2. Disable **Allow administrators to bypass configured protection rules**.
3. Restrict deployment branches and tags to the `main` branch.

Create these **environment secrets** on `maester-smoke-test`:

| Secret | Value |
| --- | --- |
| `MAESTER_SMOKE_TENANT_ID` | The Microsoft Entra **Directory (tenant) ID** (GUID) for the demo tenant. For the `elapora.com` tenant, use `0817c655-a853-4d8f-9723-3a333b5b9235`. |
| `MAESTER_SMOKE_CLIENT_ID` | The **Application (client) ID** (GUID) of the dedicated Entra app registration. |
| `MAESTER_REPORTS_APP_PRIVATE_KEY` | The PEM private key generated for the dedicated `do-not-delete-maester-reports` GitHub App. |

Create this **environment variable** on `maester-smoke-test`:

| Variable | Value |
| --- | --- |
| `MAESTER_REPORTS_APP_CLIENT_ID` | The GitHub App's Client ID. |

Do not create repository-level copies of these secrets, and remove any that
already exist there. Do not create a client secret. The published action uses
workload identity federation and GitHub's short-lived OIDC token. The GitHub
App private key is used only to mint a short-lived installation token scoped to
the private report repository.

The earlier `maester-smoke-test-pr` approval-only environment is no longer used
and can be deleted after this workflow is deployed. Pull request authorization
now comes from a current core-maintainer approval and is independently
revalidated by trusted default-branch code.

## Private GitHub report storage

GitHub Actions artifacts in the public `maester365/maester` repository inherit
that repository's read audience, so they must not contain tenant assessment
data. Store the HTML reports as private release assets instead:

1. Set the `maester365` organization base repository permission to **None**.
   Before changing it, explicitly preserve the intended readers of every
   existing private repository. In particular, preserve the current
   organization members' read access to the private `.github` repository.
2. Create a private repository named `maester365/maester-smoke-reports`.
   Disable issues, projects, wikis, and private forks. Grant
   `maester365/core-module` **Read** access and do not add other teams or direct
   collaborators. Organization owners retain their GitHub-defined
   administrative access.
3. Create an organization-owned GitHub App named
   `do-not-delete-maester-reports`:
   - Set its homepage to `https://github.com/maester365/maester`.
   - Start its description with **DO NOT DELETE** and link to the same source
     repository.
   - Disable webhooks, user authorization, and device flow.
   - Allow installation only on the `maester365` account.
   - Grant only **Contents: Read and write**. GitHub adds
     **Metadata: Read** automatically.
   - Install it using **Only select repositories** and select only
     `maester-smoke-reports`.
   - Generate one private key, store it in
     `MAESTER_REPORTS_APP_PRIVATE_KEY`, and delete the downloaded copy after
     confirming the environment secret was created.
4. Add a scheduled cleanup workflow to the private repository that deletes
   smoke-test releases and tags after 30 days.

The public workflow requests an installation token for only
`maester-smoke-reports`, explicitly reduces it to `contents: write`, and lets
`actions/create-github-app-token` revoke it when the matrix job ends. Each run
creates one private prerelease tagged `smoke-<run-id>-<attempt>` containing
assets named:

- `maester-report-quick-<os>.html`, or
- `maester-report-full-<os>.html`.

Core maintainers review a result from the private repository's **Releases**
page: open the source run's prerelease, download the required HTML asset, and
open the self-contained file locally. Release descriptions link to the source
workflow run and commit without disclosing tenant data in the public
repository. After each successful upload, the corresponding operating-system
job adds **Open the private HTML report** and **View the private release** links
to the public workflow run summary. The links disclose no report content and
resolve only for users who can read the private report repository.

## Microsoft Entra configuration

In the demo tenant:

1. Use a dedicated single-tenant app registration named
   `DO NOT DELETE - Maester GitHub Action Smoke Test` and its service principal.
   Set its **Notes** to:

   > Used by the Maester repository GitHub Actions smoke test:
   > https://github.com/maester365/maester. Authenticates only through the
   > protected maester-smoke-test GitHub Environment.

2. Grant and admin-consent the following Microsoft Graph **application**
   permissions. These are the default read-only scopes returned by
   `Get-MtGraphScope`:

   - `AuditLog.Read.All`
   - `DeviceManagementConfiguration.Read.All`
   - `DeviceManagementManagedDevices.Read.All`
   - `DeviceManagementRBAC.Read.All`
   - `DeviceManagementServiceConfig.Read.All`
   - `Directory.Read.All`
   - `DirectoryRecommendations.Read.All`
   - `EntitlementManagement.Read.All`
   - `IdentityRiskEvent.Read.All`
   - `OnPremDirectorySynchronization.Read.All`
   - `OrgSettings-AppsAndServices.Read.All`
   - `OrgSettings-Forms.Read.All`
   - `Policy.Read.All`
   - `Policy.Read.ConditionalAccess`
   - `Reports.Read.All`
   - `ReportSettings.Read.All`
   - `RoleEligibilitySchedule.Read.Directory`
   - `RoleManagement.Read.All`
   - `RoleManagementAlert.Read.Directory`
   - `SecurityIdentitiesSensors.Read.All`
   - `SecurityIdentitiesHealth.Read.All`
   - `SharePointTenantSettings.Read.All`
   - `ThreatHunting.Read.All`
   - `UserAuthenticationMethod.Read.All`

3. Add a federated identity credential to the app registration with:

   | Setting | Value |
   | --- | --- |
   | Issuer | `https://token.actions.githubusercontent.com` |
   | Subject | `repo:maester365/maester:environment:maester-smoke-test` |
   | Audience | `api://AzureADTokenExchange` |

No Azure subscription role, Exchange Online permission/role, Teams role,
write permission, mail permission, or client secret is required.

## Trigger and merge-gate strategy

- An approved review on a ready pull request targeting `main` starts the quick
  cross-platform run immediately.
- The secretless `Demo tenant quick approval trigger` workflow only records the
  review event. A separate `workflow_run` job loaded from the default branch
  independently confirms that the pull request is open, is still on its
  approved commit, and that the approving reviewer has `write`, `maintain`, or
  `admin` repository permission before requesting tenant credentials.
- The trusted runner creates a check named exactly
  **`Demo tenant quick smoke`** on the pull request's current test merge commit
  and marks it successful only when all three operating systems complete. Add
  that check to the `Protect main` ruleset's required status checks after this
  workflow has been merged to `main`; enabling it earlier would prevent this
  pull request from producing the new check.
- Every push to `main`, including a merged pull request, starts the full
  cross-platform Graph run automatically.
- A weekly Monday 05:17 UTC run exercises the full published preview.
- A manual run from `main` can select quick or full and either the `preview` or
  `latest` module channel. Manual runs from another ref fail before tenant
  access.

Neither workflow checks out or executes pull request code. The credentialed
workflow always runs trusted default-branch code, and the protected environment
only permits `main`. The listener has no token permissions or secrets. The
trusted context job can read actions and pull requests and create the explicit
merge-gate check, but cannot request an OIDC token. Only the protected matrix
receives `contents: read` and `id-token: write`.

The action is pinned to the immutable commit for `maester-action` v1.2.0.
Public result summaries, public artifacts, and telemetry remain disabled.
After Maester produces a result, the workflow transfers only the HTML report
directly to the core-only private release repository. The matrix uses
`fail-fast: false` so a failure on one operating system does not hide the other
platform results.
