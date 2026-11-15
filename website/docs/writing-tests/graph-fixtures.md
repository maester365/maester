---
title: Mock data and offline testing
description: Record Microsoft Graph responses from a test tenant, replay them with no network, and give every test a passing and a failing case.
sidebar:
  order: 4
---

# Mock data and offline testing

Maester can record the Microsoft Graph responses of a run to a folder of JSON files (a **fixture set**) and replay
them later with no network and no `Connect-Maester`. Use it to:

- write and run tests on a plane, or anywhere without a tenant
- give every test **mock data**: a fixture set in which it passes and one in which it fails
- reproduce a bug from the data that triggers it, before you fix it

Record and replay works at the level of Maester's Graph transport, behind `Invoke-MtGraphRequest`, so paging,
batching and the session cache behave as they do against a tenant. It is off unless you turn it on.

## The commands

| Command | What it does |
| --- | --- |
| `Enable-MtGraphFixture -Mode Record -Path <folder> -Scenario <name>` | Sends requests to Graph as usual and writes every response to `<folder>/<name>`, sanitised. |
| `Enable-MtGraphFixture -Mode Replay -Path <folder> -Scenario <name>` | Answers every Graph request from `<folder>/<name>`. Nothing is sent. |
| `Disable-MtGraphFixture` | Turns record or replay off, and updates the index of a recording. |
| `Get-MtGraphFixtureStatus` | Shows the mode, and the requests that had no fixture. |
| `New-MtGraphFixture` | Writes a hand-made fixture with the file name replay looks for. |
| `Update-MtGraphFixtureIndex` | Rewrites `index.json` and checks every file name, after you copy or delete fixtures by hand. |

The mode lasts for the PowerShell session. `Invoke-Maester` and `Invoke-MtTest` also turn it on from environment
variables, which suits a pipeline:

| Variable | Value |
| --- | --- |
| `MAESTER_GRAPH_FIXTURE_MODE` | `Record`, `Replay` or `Off` |
| `MAESTER_GRAPH_FIXTURE_PATH` | The folder of the fixture sets |
| `MAESTER_GRAPH_FIXTURE_SCENARIO` | The fixture set, `default` if not set |
| `MAESTER_GRAPH_FIXTURE_SANITIZE` | `0` to record without sanitising |

## Record from a test tenant

Use a test or demo tenant, not production. Sign in with the permissions a full run needs, then record:

```powershell
Connect-Maester
Enable-MtGraphFixture -Mode Record -Path ./fixtures -Scenario my-tenant
Invoke-Maester -IncludeLongRunning -IncludePreview -NonInteractive
Disable-MtGraphFixture
```

Every Graph response of the run is in `./fixtures/my-tenant`, including 403 and 404 errors, because many tests
branch on them. Throttling (429) and server errors are not recorded. Run `Invoke-Maester` a second time while
recording if you want to add tests you left out; existing fixtures are overwritten with the newer response.

## Replay offline

```powershell
Import-Module Maester
Enable-MtGraphFixture -Mode Replay -Path ./fixtures -Scenario my-tenant
Invoke-Maester -NonInteractive
Get-MtGraphFixtureStatus
```

No `Connect-Maester` is needed. Inside Maester, `Get-MgContext` returns the connection the fixture set was
recorded with (tenant, account, auth type and scopes), so connection checks pass and tests that read scopes take
the same branch. A replayed run sends no telemetry.

To run one test while you write it:

```powershell
Enable-MtGraphFixture -Mode Replay -Path ./powershell/tests/fixtures/graph-replay -Scenario badly-configured
Invoke-MtTest -Path ./tests/maester/entra/Test.MT.1073.ps1
```

### When a fixture is missing

A request with no fixture fails with an error that names the request and the file that would answer it:

```text
Graph replay has no fixture for this request in './fixtures/my-tenant':
  GET beta/policies/authorizationpolicy (file graph/get_beta_policies_authorizationpolicy_1a2b3c4d5e.json)
```

The test that made it ends in an error, and at the end of `Invoke-Maester` one warning lists every missing request
of the run. `(Get-MtGraphFixtureStatus).Missing` returns the same list, so a pipeline can fail on it. Record the
requests again, or write them with `New-MtGraphFixture`.

### What replay does not cover

Only Microsoft Graph is recorded. In replay:

- Tests that declare another service (`ExchangeOnline`, `SecurityCompliance`, `Teams`, `SharePointOnline`, `Azure`,
  `AzureDevOps`, `GitHub`, `ActiveDirectory`, Dataverse) are **skipped**, with the reason *Graph replay serves
  Microsoft Graph only*. They are never sent to the service, even if you are connected to it.
- A request sent with `Invoke-MgGraphRequest` directly instead of `Invoke-MtGraphRequest`, such as a report
  downloaded to a file, cannot be replayed. The test is skipped with a reason that says so.
- Maester Packs and Pester-format custom tests that call `Get-MgContext` or `Invoke-MgGraphRequest` themselves see
  the real Graph SDK, not the recorded connection. Their calls to `Invoke-MtGraphRequest` are replayed.
- DNS lookups (SPF, DKIM, DMARC tests) are not recorded.

## How a fixture set is laid out

```text
fixtures/
  my-tenant/
    scenario.json   the connection it was recorded with, and the result each test should have
    index.json      every request and its file, sorted by key
    .salt           the sanitisation secret of a recording; never commit it (.gitignore lists it)
    graph/
      get_v1.0_organization_3137e0e0cd.json
      get_beta_policies_authorizationpolicy_1a2b3c4d5e.json
```

Each file holds one request and its response, and never a header or token:

```json
{
  "request": { "method": "GET", "uri": "v1.0/organization", "key": "GET v1.0/organization" },
  "response": { "status": 200, "body": { "value": [ { "id": "fa4efa4e-..." } ] } }
}
```

The **key** says which request a fixture answers. It is the same for the same request every time:

- the method, and the API version (`v1.0` or `beta`)
- the path without the Graph endpoint, decoded and in lower case, so it does not matter which cloud recorded it
- the query parameters sorted by name, values decoded, so their order does not matter
- for a POST, a hash of the body with its JSON members sorted

Headers such as `ConsistencyLevel` are not part of the key. The file name is the method, version and path,
followed by a hash of the key. To find the fixture of a request, search `index.json` for its path.

A **paged** response is stored page by page. The fixture of a page that has more points to the next with a stable
link, the same request with `$skiptoken=maester-page-2` (then `-3` and so on), and the next page is stored under
that link. Graph's own skip token is never written.

A **batch** is stored as one fixture per request in it, so replay answers the same requests whether or not they are
batched, and with any batch size.

## Sanitisation

Recording replaces tenant data with stable fake values before anything is written. It is on by default; use
`-NoSanitize` only for a fixture set that never leaves your computer.

| Data | Becomes |
| --- | --- |
| Tenant ID, object IDs and every other GUID | `fa4efa4e-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Email addresses and user principal names | `user-1a2b3c4d@fake9f8e7d.example` |
| Guest user principal names | `guest-1a2b3c4d#EXT#@fake9f8e7d.onmicrosoft.com` |
| The tenant's domains, wherever they appear | `fake9f8e7d.example`, or `fake9f8e7d.onmicrosoft.com` (and `.sharepoint.com` and the other Microsoft suffixes) |
| Display names of users, groups, applications, policies | `user-1a2b3c`, `group-4d5e6f`, `policy-...` |
| Given name, surname, phone numbers, address, on-premises names and SIDs | `redacted-1a2b3c` |

Each fake value is a keyed hash (HMAC-SHA256) of the real one, with a secret salt kept in the fixture set's `.salt`
file. The same real value always becomes the same fake value, so relationships survive: a group member's ID is still
the ID of the user, and a filter on a display name still finds the object. A fake value is never replaced twice.

These are **kept**, because checks compare data with them:

- every GUID written in Maester's own source: role template IDs (Global Administrator is
  `62e90394-69f5-4237-9190-012177145e10`), Microsoft application and permission IDs, licence SKU and service plan IDs.
  Add more with `-PreserveValue`.
- the display names of built-in objects, such as directory roles
- Microsoft's own domains (`microsoft.com`, `windows.net` and others), and the `#EXT#` marker of a guest

### Limits

Sanitisation reduces what a fixture set gives away. It does not make a recording safe to publish without a review.

- **Free text is not understood.** A policy description, a group's description or a note that names a person, the
  company or a project is kept, unless it contains an address, a GUID or one of the tenant's domains.
- **IP addresses, named location ranges, certificates and other binary values are kept**, because tests read them.
- **A domain is only replaced once Maester knows it is the tenant's**: from the tenant's verified domains (read when
  the recording starts), from an address, or from a domain object. A domain that appears only in free text may stay.
- **The salt is the key to the fake values.** Anyone with it can check whether a guessed value (a tenant ID that is
  public, for example) is in the fixture set. Keep `.salt` out of git; delete it once you are done recording.
- **A GUID that happens to be in Maester's source is kept**, as a well-known ID.

Look through a fixture set before you share it. The unit tests check the fixture sets in this repository for any GUID
that is not fake or well-known.

## Add a scenario

The fixture sets that ship with the unit tests are in `powershell/tests/fixtures/graph-replay`:

| Scenario | What it is |
| --- | --- |
| `well-configured` | A tenant configured as Maester recommends: tests pass. |
| `badly-configured` | A tenant with the settings Maester flags: tests fail. |
| `empty` | A new tenant with no licences, no synchronization and nothing assigned. |
| `insufficient-permissions` | A tenant where Graph answers 403 to some requests. |

To add one, create a folder with a `scenario.json`, then write its fixtures:

```json
{
  "name": "guest-heavy",
  "description": "A tenant with many guests and loose external collaboration settings.",
  "sanitized": false,
  "context": {
    "tenantId": "fa4efa4e-0000-4000-8000-000000000000",
    "account": "admin@contoso.onmicrosoft.com",
    "authType": "Delegated",
    "environment": "Global"
  },
  "expectations": {
    "MT.1234": "Failed"
  }
}
```

`context` is what `Get-MgContext` returns in replay. Leave out `scopes` to get every scope Maester asks for, or list
them to test how a check handles a missing one. `expectations` is the result each test must have in this scenario:
`Passed`, `Failed`, `Skipped`, `Investigate` or `Error`.

Most scenarios need the two requests every run makes for the tenant context, `v1.0/organization` and
`v1.0/subscribedSkus`. Copy them from an existing scenario and change what you need, then run
`Update-MtGraphFixtureIndex`.

## Mock data for every test

Every new or changed test that reads Microsoft Graph ships with mock data: fixtures in at least one scenario in which
it **passes** and one in which it **fails**, with both results in the scenarios' `expectations`.

1. Write the test. Then turn on replay against the scenario you want it to pass in, and run it:

   ```powershell
   Import-Module ./powershell/Maester.psd1 -Force
   Enable-MtGraphFixture -Mode Replay -Path ./powershell/tests/fixtures/graph-replay -Scenario well-configured
   Invoke-MtTest -Path ./tests/maester/entra/Test.MT.1234.ps1
   (Get-MtGraphFixtureStatus).Missing
   ```

2. `Missing` lists each request the test made that has no fixture. Write each one, with data that makes the test pass:

   ```powershell
   New-MtGraphFixture -Path ./powershell/tests/fixtures/graph-replay -Scenario well-configured `
       -Uri 'beta/policies/authorizationPolicy' `
       -Response @{ id = 'authorizationPolicy'; allowInvitesFrom = 'adminsAndGuestInviters' } `
       -Note 'MT.1234 passes: only admins and guest inviters may invite guests.'
   ```

   If you have a test tenant, record instead: `Enable-MtGraphFixture -Mode Record`, run the test, then copy the files
   you need into the scenario.

3. Repeat in `badly-configured` (or a scenario of your own) with data that makes the test fail. Use fake IDs that
   start with `fa4efa4e`, and domains such as `contoso.onmicrosoft.com`.
4. Add the test to the `expectations` of both `scenario.json` files.
5. Run the unit tests for mock data:

   ```powershell
   ./powershell/tests/pester.ps1 -Include 'GraphFixture*'
   ```

`GraphFixtureScenarios.Tests.ps1` runs every expectation in replay and fails if a result changes or a fixture is
missing. `GraphFixtureCoverage.Tests.ps1` fails when a Graph test has no passing and failing case. Tests that read
another service, and the generated EIDSCA and ORCA tests, are not covered by the rule yet.

The tests that had no mock data when the rule came in are listed in
`powershell/tests/fixtures/graph-replay/coverage-baseline.txt`. The list only shrinks: when you give one of them mock
data, or change it in a pull request, remove its line. A new test can never be added to it.

MT.1073 (a tenant setting, with a skip and a 403) and CIS.M365.1.1.3 (directory objects over two pages) are worked
examples to copy.

## Reproduce a bug first

When a bug is reported against a test:

1. **Capture the data.** Ask the reporter for the Graph responses (recorded with sanitisation on, then reviewed), or
   write fixtures by hand that reproduce what they describe.
2. **Add a regression scenario.** Put the fixtures in a scenario named after the issue, such as
   `issue-1234-null-conditions`, with the result the test *should* give in `expectations`.
3. **See it fail.** Run `./powershell/tests/pester.ps1 -Include 'GraphFixtureScenarios*'`: the expectation fails,
   which shows the bug.
4. **Fix the test**, and run it again until it passes. Commit the scenario with the fix, so the bug cannot come back.
