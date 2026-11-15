# Graph fixture sets

Mock data for Maester's tests: Microsoft Graph responses that Graph replay (`Enable-MtGraphFixture -Mode Replay`)
serves with no network. One folder per scenario:

| Scenario | What it is |
| --- | --- |
| `well-configured` | A tenant configured as Maester recommends: tests pass. |
| `badly-configured` | A tenant with the settings Maester flags: tests fail. |
| `empty` | A new tenant: no licences, no synchronization, nothing assigned. |
| `insufficient-permissions` | Graph answers 403 to some requests. |

Each scenario has `scenario.json` (the connection replay reports and the result each test must have, in
`expectations`), `index.json` (every request and its file) and `graph/` (one file per request).
`GraphFixtureScenarios.Tests.ps1` runs every expectation; `GraphFixtureCoverage.Tests.ps1` checks that every Graph
test has a passing and a failing case, except the tests listed in `coverage-baseline.txt`, a list that only shrinks.

Everything here is hand-written and fake: IDs start with `fa4efa4e`, domains are Contoso, Fabrikam, Northwind and
Tailspin. Never add real tenant data or a `.salt` file.

How to add mock data for a test, record from a tenant and reproduce a bug: `website/docs/writing-tests/graph-fixtures.md`.
