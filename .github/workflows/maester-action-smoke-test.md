# Maester action tenant smoke test

`maester-action-smoke-test.yaml` exercises the published standard
`maester365/maester-action` on Linux, Windows, and macOS against a real
Microsoft 365 tenant. It runs one fast, platform-neutral Graph test (`MT.1068`)
and verifies that Maester produced a complete result for the configured tenant.

The check intentionally accepts either `Passed` or `Failed` for `MT.1068`.
The test tenant's policy state is not a release gate. Authentication errors,
Graph errors, skipped/not-run tests, missing results, or the wrong test/tenant/OS
fail the workflow.

## Protected environment configuration

In `maester365/maester`, create a GitHub Actions environment named exactly
`maester-smoke-test`. Configure its deployment protection rules before adding
credentials:

1. Add `maester365/core-module`, the core Maester maintainer GitHub team, as
   the only required reviewer. Do not add outside collaborators, bots, or
   broad contributor teams.
2. Enable **Prevent self-review**.
3. Disable **Allow administrators to bypass configured protection rules**.
4. Restrict deployment branches and tags to the `main` branch.

Create these **environment secrets** on `maester-smoke-test`:

| Secret | Value |
| --- | --- |
| `MAESTER_SMOKE_TENANT_ID` | The Microsoft Entra **Directory (tenant) ID** (GUID) for the test tenant. For the `elapora.com` tenant, use its directory ID rather than the domain name. |
| `MAESTER_SMOKE_CLIENT_ID` | The **Application (client) ID** (GUID) of the dedicated Entra app registration in that tenant. |

Do not create repository-level copies of these secrets, and remove any that
already exist there. Do not create a client secret. The published action
supports workload identity federation and authenticates with GitHub's
short-lived OIDC token.

GitHub evaluates the environment's required-reviewer and branch rules before
starting each credentialed matrix job. The job cannot read the environment
secrets or request an OIDC token until a core maintainer approves the pending
deployment.

## Microsoft Entra configuration

In the test tenant:

1. Create a dedicated single-tenant app registration named
   `DO NOT DELETE - Maester GitHub Action Smoke Test` and its service principal.
   Set its **Notes** to:

   > Used by the Maester repository GitHub Actions smoke test:
   > https://github.com/maester365/maester. Authenticates only through the
   > protected maester-smoke-test GitHub Environment.

2. Grant and admin-consent these Microsoft Graph **application** permissions:
   - `Directory.Read.All`
   - `Policy.Read.All`
3. Add a federated identity credential to the app registration with:

   | Setting | Value |
   | --- | --- |
   | Issuer | `https://token.actions.githubusercontent.com` |
   | Subject | `repo:maester365/maester:environment:maester-smoke-test` |
   | Audience | `api://AzureADTokenExchange` |

No Azure subscription role, Exchange Online permission/role, Teams role, mail
permission, or client secret is required for this scoped smoke test. The app
needs only read access; `MT.1068` may pass or fail without affecting the smoke
result.

## Trigger and disclosure strategy

- A successful `publish-module-preview` run starts the cross-platform smoke
  test against the newly published preview module, then waits for a core
  maintainer to approve the protected-environment deployment.
- A weekly Monday 05:17 UTC run catches action, runner-image, dependency, and
  tenant-authentication drift, subject to the same approval.
- A manual run from `main` can exercise either the `preview` or `latest` module
  channel. Use this as the explicit pre-release check; it also requires approval.
- Pull requests and ordinary pushes are not workflow triggers. Manual runs from
  another ref fail in the uncredentialed preflight job without requesting
  approval or reading secrets.
- The federated credential trusts only jobs assigned to the
  `maester-smoke-test` environment. The environment restricts deployments to
  `main` and its only required reviewer is the core maintainer team.

The workflow has no default token permissions. Only the protected,
credentialed job receives `contents: read` and `id-token: write`; the
uncredentialed preflight job cannot mint an OIDC token. No trigger or broader
permission is needed for the environment gate: GitHub applies it to manual,
scheduled, and `workflow_run` executions before the job starts.

The action is pinned to the immutable commit for `maester-action` v1.2.0.
Result summaries, HTML reports, artifacts, and telemetry are disabled because
this is a public repository and tenant assessment data is not needed to prove
execution. The matrix uses `fail-fast: false` so a failure on one operating
system does not hide the other platform results.
