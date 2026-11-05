# Design: the defender's path

> **Status: accepted for implementation, 2026-11-05.** The owner accepted every recommendation in section 17.
> Targets Maester 3.1: main is in the 3.0 code freeze from 7 November 2026.

## 1. Summary

Attack-path tools show the route an attacker takes. The defender's path shows the order a defender has to work
in: what has to be in place before a fix works, what a fix unlocks, and whether the tenant is ready for it.
Microsoft Learn documents this order page by page, but no assessment tool uses it. The owner ruled on 5 November
2026 that it should be Maester's strong point.

The design adds four things:

- **A catalogue of steps.** A step is one change an administrator makes ("Assign a compliance policy for each
  platform") or one state the tenant must reach ("Devices that sign in are compliant"). The catalogue says
  how steps relate (requires, requires one of, only when, recommended first, conflicts) and how to switch each
  one on. Every relationship cites Microsoft Learn in Maester's own words. Goals group the steps that lead to
  one outcome, such as "Require compliant devices".
- **A `Step` attribute on tests.** A test names the step it verifies. Tests in different suites that check the
  same setting name the same step, so CIS, CISA, Maester and Zero Trust checks fall into one place.
- **`Steps` and `Goals` in the result.** For every step in scope the engine works out its status (Done, Not
  done, Unknown, Not checked, Not applicable), whether it can start (Ready, Blocked, Unconfirmed), what blocks
  it and what it unlocks, and its place in the order. The report, the console, CSV and Markdown all read
  these. None of them works the order out again.
- **Readiness checks.** These are new tests for prerequisites that are states rather than settings, such as the
  share of Windows devices that are joined. They report a count and pass above a threshold.

A run without any test that names a step looks exactly as it does today.

## 2. The problem

The action plan ranks failed tests by severity, user impact and implementation cost (`priority()` in
`report/src/lib/model.ts`). It knows nothing about order. In a tenant with no Intune compliance policies it can
put MT.1001 ("At least one Conditional Access policy is configured with device compliance") near the top.
Following that advice before devices are enrolled and covered by compliance policies locks users out. The
guide for MT.1001 says only "Review the configuration described above."

Microsoft Learn is explicit about the order for this change and many others:

| Change | What Learn says comes first |
| --- | --- |
| Require a compliant device in Conditional Access | An Intune compliance policy, and at least one compliant device, before the policy is on |
| User-risk and sign-in-risk policies | Users registered for MFA, and password writeback for synced users. Remediate existing risky users first |
| Token protection | Windows devices joined or registered, Apple devices managed with the SSO plug-in. Pilot in report-only |

Three things make this hard to bolt onto the current model:

- Several suites check the same setting. MT.1001 and ZTA.24824 both check that Conditional Access requires a
  compliant device. Prerequisites tagged on each test would be repeated and would drift.
- Many prerequisites are not settings. "Devices are enrolled" is a state of the tenant, so it needs its own
  node and often its own check.
- Some prerequisites have alternatives, and some apply only to some tenants. Password writeback, for example,
  matters only for synced users.

So the unit is the change, not the test: tests point at a step, and the catalogue holds the facts. This is the
model the framework files already use. The mapping lives on the test's `Control`, and
`tests/<suite>/frameworks/<key>.json` holds the requirements.

## 3. Terms

| Term | Meaning |
| --- | --- |
| Step | One change or one tenant state, with an ID such as `intune.compliance-policies` |
| Prerequisite | A step that another step requires, requires one of, or recommends first |
| Goal | An outcome and the step that achieves it, such as "Require compliant devices". Its steps are that step and its prerequisites, followed down every level |
| Readiness check | A test whose step is a tenant state. It reports a share and passes above a threshold |
| Verifying tests | The tests whose `Step` names a step |

The name shown to readers is "Defender's path". In the report it reads as "Defender's path · Require compliant
devices · 3 of 7 steps done".

## 4. The catalogue

### 4.1 Files

```
powershell/assets/steps/
  goals.json        the goals, in the order the report shows them
  entra.json        the steps whose Product is entra
  intune.json
  exchange.json
  defender.json
  ...               one file per product key that has steps
```

The catalogue ships in the module beside the taxonomy registry and is read at run time, so it needs no build
step. Files are split by product to keep merge conflicts small. A step's file is named after the product in its
ID.

Each file has this shape:

```json
{
  "$schema": "./steps.schema.json",
  "Product": "entra",
  "Steps": [ ]
}
```

`powershell/assets/steps/steps.schema.json` describes both file types so that editors validate as you type.

### 4.2 A step

```json
{
  "Id": "entra.ca-require-compliant-device",
  "Title": "Require a compliant device in Conditional Access",
  "Summary": "Sign-ins from devices Intune does not mark compliant are blocked.",
  "Requires": ["intune.compliance-policies", "intune.devices-compliant", "entra.emergency-access-excluded", "entra.ca-exclude-sync-accounts"],
  "RequiresOneOf": [],
  "RecommendedFirst": ["intune.mark-unassigned-noncompliant"],
  "Conflicts": [],
  "OnlyWhen": [],
  "Rollout": [
    "Create the policy in report-only mode and review the sign-ins it would block.",
    "Turn it on for a pilot group.",
    "Turn it on for all users, keeping the emergency access accounts excluded."
  ],
  "Sources": [
    {
      "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-compliance",
      "Mirror": "entra-docs-mirror",
      "Note": "Create an Intune compliance policy first, and have at least one compliant device, or the policy blocks everyone.",
      "Reviewed": "2026-11-05"
    }
  ]
}
```

| Field | Required | Rule |
| --- | --- | --- |
| `Id` | yes | `<product-key>.<name>`. The product key comes from the taxonomy, and the name is lowercase kebab-case. Stable once shipped, like a test ID |
| `Title` | yes | Imperative for a change ("Require…", "Assign…"), a statement for a state ("Devices that sign in are compliant"). One line |
| `Summary` | yes | One sentence on what changes for users or the tenant |
| `Requires` | no | Steps that must be done first, or the change fails or locks users out |
| `RequiresOneOf` | no | Groups of at least two steps. Any one step in a group is enough |
| `RecommendedFirst` | no | Steps that make this one safer or more useful. They never block |
| `Conflicts` | no | Steps that must be off before this one can be on. Declared on the step that needs the other one off |
| `OnlyWhen` | no | Conditions from section 4.4. All must hold, or the step is Not applicable |
| `Rollout` | no | Ordered sentences on how to switch it on safely |
| `Sources` | yes | At least one. See section 4.5 |
| `Unchecked` | when no test names the step | Why Maester cannot check it yet, in one sentence |

A step has no severity, cost or licence of its own. Those stay on its verifying tests, so they are never
declared twice.

### 4.3 Relationships

| Relationship | Meaning | Effect on the plan | Example |
| --- | --- | --- | --- |
| Requires | Must be done first | Blocks the step while the prerequisite is Not done | Compliant-device CA requires compliance policies |
| RequiresOneOf | Any one of a group will do | Blocks the step while every step in the group is Not done | A managed-device grant is met by a compliant device or a hybrid joined one |
| RecommendedFirst | Works without it, but is safer after it | Orders only, never blocks | Remediate high-risk users (MT.1260) before the user-risk policy |
| Conflicts | The other step must be off first | Blocks the step while the conflicting step is Done | Conditional Access policies can't be turned on while security defaults are on |
| OnlyWhen | Applies to some tenants only | Not applicable when a condition is false | Password writeback, only for hybrid identity |
| Rollout | How to switch it on | Shown in How to fix | Report-only, a pilot group, then everyone |

### 4.4 Conditions

`OnlyWhen` takes keys from a closed list, so that the engine can evaluate every condition without running a
check:

| Condition | True when | Read from |
| --- | --- | --- |
| `hybrid-identity` | The tenant syncs identities from on-premises | `onPremisesSyncEnabled` on the organization, which the tenant context already reads |
| `license:<service plan>` | The tenant has the service plan, written as in a test's `License` | The licences the tenant context already reads |

If a condition cannot be read, for example because Graph is not connected, the step is Unknown, not Not
applicable. New conditions are added to this list and to the engine together.

### 4.5 Sources and wording

- `Url` is the Learn page with no locale, the form the check guides use.
- `Mirror` names the Learn mirror repository that holds the page, out of the nine `merill/*-docs-mirror`
  repositories. The tooling of section 13 finds the file from the URL, so the path is not written by hand.
- `Note` is Maester's own wording of what the page says about order, up to 200 characters. Never copy
  Microsoft's text.
- `Reviewed` is the date someone last read the page against the step. The change-detection workflow compares
  it with the mirror's history.
- A relationship that Learn does not document can cite a maintainer instead:
  `{ "Maintainer": "merill", "Note": "...", "Reviewed": "..." }`. The unit tests count these, and the review keeps
  them rare.

### 4.6 Goals

```json
{
  "Goals": [
    {
      "Id": "compliant-devices",
      "Title": "Require compliant devices",
      "Summary": "Only devices that Intune manages and marks compliant can reach Microsoft 365.",
      "Step": "entra.ca-require-compliant-device"
    }
  ]
}
```

A goal's steps are not listed. They are its `Step` plus everything that step requires, requires one of, or
recommends first, followed down every level. A step can belong to several goals. For example,
`entra.emergency-access-excluded` sits under compliant devices, risk policies and privileged access. Goal IDs are lowercase
kebab-case with no product prefix, because a goal often spans products.

## 5. The `Step` attribute

```powershell
[MaesterTest(
    Id      = 'MT.1001',
    Title   = 'At least one Conditional Access policy is configured with device compliance.',
    Product = 'entra',
    Feature = 'conditional-access',
    Step    = 'entra.ca-require-compliant-device',
    ...
)]
```

| Property | Type | Values | Built-in tests | Notes |
| --- | --- | --- | --- | --- |
| `Step` | string[] | step IDs | optional | Usually one value, at most three. Pattern `^[a-z0-9][a-z0-9-]*\.[a-z0-9][a-z0-9-]*$`, at most 80 characters. Stored in lowercase |

- It is added to `MaesterTestAttribute` in `src/Maester.Engine` and to `powershell/assets/MaesterTestSchema.psd1`
  together, since a unit test compares them. The DLL in `powershell/lib/` is rebuilt.
- A built-in test must name steps that exist in the catalogue, or the build fails. A custom test or a pack test
  may name any built-in step. A step ID the catalogue does not have stays on the row with a warning and is left
  out of `Steps`. Custom catalogues are not part of this design (section 18).
- A family instance can set `Step` the way it sets `Product` and `Feature` on the
  `feat/zta-taxonomy-mapping` branch (`Get-MtInstanceAttribute`). The Zero Trust pack takes each test's
  steps from its hand-kept `taxonomy.json`, next to `AlsoCheckedBy`.
- Pester-format tests have no `Step`.
- Tests with different definitions of done get different steps, even when they read the same setting. CIS
  5.2.2.9 accepts a compliant or a hybrid joined device. MT.1001 needs device compliance. So CIS 5.2.2.9 names
  `entra.ca-require-managed-device` and MT.1001 names `entra.ca-require-compliant-device`. Otherwise one step
  would pass and fail in the same run.
- `Step` is not a taxonomy tag and adds no tag. `Get-MtTest -Step` and `Invoke-Maester -Step` select by it
  (section 8).

## 6. A step's status in a run

### 6.1 Status

A step's status comes from the results of its verifying tests in this run. A test the run did not select
counts as not run.

| Status | Rule, checked in this order |
| --- | --- |
| Not applicable | An `OnlyWhen` condition is false, or every verifying test that ran was skipped as `NotApplicable` |
| Not done | Any verifying test failed |
| Unknown | No test failed, and at least one ended as Investigate, Error or Skipped. The reason codes are kept |
| Done | At least one verifying test passed, and every test that ran passed |
| Not checked | No verifying test ran. `Reason` is `NotSelected` when tests exist and `NoCheck` when none do (the step is `Unchecked`) |

Done means done as far as this run checked. The step record says how many of its tests ran ("1 of 2 checks
ran"). The three statuses Not done, Unknown and Not checked never blur. Unknown says the run could not tell,
Not checked says it did not look, and neither is counted as Not done.

### 6.2 Readiness

Readiness applies to steps that are Not done, Unknown or Not checked. Prerequisites that are Not applicable
count as met.

| Readiness | Rule |
| --- | --- |
| Blocked | A `Requires` step is Not done, every step of a `RequiresOneOf` group is Not done, or a `Conflicts` step is Done. `BlockedBy` lists them |
| Unconfirmed | Not blocked, but a prerequisite is Unknown or Not checked. `Unconfirmed` lists them |
| Ready | Every `Requires` step is Done and every `RequiresOneOf` group has a step that is Done |

`RecommendedFirst` never changes readiness. It appears as "Recommended first" with the step's status.

### 6.3 Order

Steps get a `Rank` so that every output lists them in the same order:

1. **Group:** Ready, then Unconfirmed, then Blocked. Within the Unconfirmed group, the prerequisites to check
   come right before the steps they would confirm.
2. **Dependencies:** `Requires`, `RequiresOneOf` and `RecommendedFirst` edges, in topological order. The unit
   tests guarantee that the graph has no cycles.
3. **Value:** a step's own value is the highest `priority()` among its failed tests. Its unlock value is the sum
   of the values of the Not done steps that depend on it, at any depth. "Enroll devices in Intune" therefore
   ranks by the controls it enables, not by its own severity.
4. **ID**, so the order is stable.

`priority()` moves from the report into the engine as `Get-MtTestPriority`, so that the console and Markdown rank
the same way. The report keeps its copy for results that have no `Steps`. A unit test checks that the two give
the same numbers on the golden fixture.

The defender's path adds no score. Pass rates, framework coverage and the headline numbers are unchanged.

## 7. Results

### 7.1 Rows

Every native row gains `Step` (a list, empty when the test names none). A family instance's row carries the
instance's value.

### 7.2 `Steps` and `Goals`

Two top-level properties. Like `Packs` and `Attachments`, they are written only when they have content (here,
when a row in the result names a step), so every other result stays as it is.

```json
"Steps": [
  {
    "Id": "entra.ca-require-compliant-device",
    "Title": "Require a compliant device in Conditional Access",
    "Summary": "Sign-ins from devices Intune does not mark compliant are blocked.",
    "Product": "entra",
    "Goals": ["compliant-devices"],
    "Status": "NotDone",
    "Reason": null,
    "Readiness": "Blocked",
    "BlockedBy": ["intune.compliance-policies"],
    "Unconfirmed": ["intune.devices-compliant"],
    "Unlocks": [],
    "Rank": 9,
    "Tests": [
      { "Id": "MT.1001",   "Result": "Failed" },
      { "Id": "ZTA.24824", "Result": "NotRun", "ReasonCode": "NotInRun" }
    ],
    "Earlier": null,
    "Requires": ["intune.compliance-policies", "intune.devices-compliant", "entra.emergency-access-excluded", "entra.ca-exclude-sync-accounts"],
    "RequiresOneOf": [],
    "RecommendedFirst": ["intune.mark-unassigned-noncompliant"],
    "Conflicts": [],
    "OnlyWhen": [],
    "Rollout": ["..."],
    "Sources": [{ "Url": "...", "Note": "...", "Reviewed": "2026-11-05" }]
  }
],
"Goals": [
  {
    "Id": "compliant-devices",
    "Title": "Require compliant devices",
    "Step": "entra.ca-require-compliant-device",
    "Steps": ["entra.emergency-access-excluded", "intune.compliance-policies", "..."],
    "Done": 3,
    "Applicable": 7,
    "Status": "InProgress"
  }
]
```

- **Scope.** A step is in scope when a row that ran names it, or when it is a prerequisite, at any depth, of
  such a step. A goal is in scope when any of its steps is. A row ran when its result is anything but
  `NotRun`.
- **Tests come from the inventory, not only the rows.** `Tests` lists every test the engine knows that names
  the step: built-in tests from the catalog, custom tests that were discovered, and pack tests from each pack's
  catalogue. A test with no row has `Result` `NotRun` and `ReasonCode` `NotInRun`. The report can then name the
  command that checks it. This is how `Frameworks` already lists requirements that no row checks.
- **`Earlier`** is set on a step that is Not checked in this run when an earlier result in the output folder
  checked it: `{ "Status": "Done", "ExecutedAt": "...", "File": "..." }`. It is never mixed into this run's
  status or counts. `Get-MtPreviousResult` gains `LastKnown`, which is the newest earlier result for each test ID
  a step in scope names. It reads only files that `History` already lists, and only when some step in scope is
  Not checked. Today `Results` covers the newest earlier run only, and after a one-check run that run says
  little.
- **Goal status** is `Done` when every applicable step is Done, `NotStarted` when none is, and `InProgress`
  otherwise. When a step is Unknown or Not checked, the goal shows that count next to its progress.
- Built by `Get-MtResultStep` (internal, `powershell/internal/report/`) in `ConvertTo-MtMaesterResult`, next to
  `Get-MtResultFramework`. `Merge-MtPartitionResult` builds it again from the merged rows, as it does
  `Frameworks`, so that a multi-tenant or partitioned run is ordered as a whole.
- Additive, so the result schema moves from 2.1 to 2.2, and `website/docs/result-schema.md` documents both
  properties.

### 7.3 Other outputs

| Output | Change |
| --- | --- |
| CSV and Excel | `Step`, `Readiness` and `BlockedBy` columns on each test row |
| Markdown report | A "Do these first" list: the first five Ready steps, each with its failed tests. A one-line count of Blocked and Unconfirmed steps |
| JUnit XML | None |
| Console | One line in the run summary when `Steps` is present: `Defender's path: 3 ready · 2 blocked · 1 to check first` |

## 8. Selection

| Parameter | Config key | Selects |
| --- | --- | --- |
| `-Step` | `Selection.Step` | Tests whose `Step` matches. Takes a list, and `*` wildcards work (`intune.*`) |
| `-IncludePrerequisites` | `Selection.IncludePrerequisites` | Adds the verifying tests of every prerequisite of the steps that the selected tests name, at any depth |

- They combine with the other selectors as in section 4 of the
  [test attributes design](./maester-3.0-test-attributes.md). `-IncludePrerequisites` is applied last, so
  `Invoke-Maester -TestId MT.1001 -IncludePrerequisites` runs MT.1001 and the checks of everything it depends on.
- Prerequisite tests that are Preview or LongRunning are included when `-IncludePrerequisites` reaches them,
  the same way an exact `-TestId` includes them. The ZTA family is the exception: it is included only when
  `-Suite ZTA` or `-IncludeLongRunning` is also given, because it runs the whole assessment. Its steps then show
  as Not checked with that command.
- `Get-MtTest -Step` filters the same way. There is no goal selector, because `-Step <goal step>
  -IncludePrerequisites` selects a whole goal. No new public command is added in Phase 1.

## 9. Report

Every view below is hidden when the result has no `Steps`, the same way views without data are hidden today.

- **Action plan.** Opens with the defender's path: three groups of step cards in `Rank` order: Ready now, Check
  first and Blocked. A card shows the step, its failed tests, what it unlocks ("unlocks 2 steps, 6 failed
  checks"), its rollout and its sources. Below the groups, a lane for each goal in scope shows its steps in
  order with a status chip each. The existing ranked list of failed tests stays below that. A failed test whose
  step is Blocked moves after the tests that can be fixed now and shows "Blocked by …".
- **Test page.** When the test's step has prerequisites, a "Before you fix this" panel lists each one with its
  status and where that status came from: this run, an earlier run (with its date), or Not checked. It also gives
  the command that checks what is missing:
  `Invoke-Maester -TestId MT.1001 -IncludePrerequisites`. The How to fix tab adds the step's rollout.
- **Overview.** One card: Ready now, Blocked and Check first counts, with a link to the action plan.
- **Small runs.** With one to three tests that ran, there are no lanes. Each test page carries "Before you fix
  this" (section 10).

The report reads `Steps` and `Goals` as written and works out nothing itself.

## 10. Scoping rules

The rule for every output: scope everything to what ran, and never infer a status for a test that did not run.

| Run | Report | Console | Result |
| --- | --- | --- | --- |
| Full run | Groups and a lane for every goal in scope | The summary line | `Steps`, `Goals` |
| One suite or product | Only goals with a step in scope. A step whose tests were not selected shows "Not checked in this run" and the command to include them | The line, when a step is in scope | The steps in scope, with all their tests |
| One to three tests | No lanes. "Before you fix this" on each test page, with `Earlier` statuses and their dates | Nothing extra | The same |
| Tests that name no step (GitHub, Azure DevOps, Active Directory, most custom tests) | No change. The views stay hidden | No change | No `Steps` |
| A verifying test that could not run (service not connected, no licence) | The step is Unknown, with the reason and the fix command, and never Not done | Counted with the tests that did not run | `Status` `Unknown` with the reason codes |

## 11. Readiness checks

Seven steps in the first catalogue have no check. Two of them get readiness checks in Phase 1. Each check is a native
test in `tests/maester/<service>/`. It reads Graph through `powershell/internal/services/<service>/` helpers,
reports a count and a share, and lists the objects that hold the step back as affected objects. It passes when
the share is at least its `MinimumShare` parameter (an `int`, default `95`).

| Step | Check | Reads | Notes |
| --- | --- | --- | --- |
| `intune.devices-compliant` | Devices that sign in are compliant | `devices` that signed in within 30 days, by `isManaged` and `isCompliant` | Lists the devices that would be blocked. Devices with no Entra identity can't be seen this way, which the result says |
| `entra.mfa-registered` | Enabled member users are registered for MFA | `reports/authenticationMethods/userRegistrationDetails` | Needs Entra ID P1. Excludes the emergency access accounts |

Later: phishing-resistant method registration for all users (ZTA.21782 covers privileged users only),
password writeback once a Graph API reports it, security defaults being off in tenants licensed for
Conditional Access (section 15), and hybrid join and Windows device registration, which need sign-in data to
see the devices that have no identity yet. The Defender–Intune connector is partly covered already.
MT.1098 checks that Mobile Threat Defense connectors are healthy. Whether it fails when the Defender connector
is missing is confirmed in the expert pass.

These are new MT checks. IDs are reserved on issue #697, and each goes through the duplicate review and the
attribute review in `AGENTS.md`. Their attribute values come from the rubric, not from this design.

## 12. Object facts

The Zero Trust facts work (`Add-MtAffectedObjectFact`, maester365/maester#2681) puts facts on
listed objects: join type, managed and compliant for devices, MFA and passwordless for users. They are the
drill-down behind a lane ("38 devices aren't managed"). They cannot replace readiness checks, because facts
attach only to objects the run lists and come from the Zero Trust export only when it ran. Readiness checks
write facts too.

This design asked that work to give each fact a stable key and a raw value before the command ships, so that a
lane's drill-down never parses display text. It did, in maester365/maester#2681: a fact has `Name`, `Value`
(display text), `Tone`, an optional `Key` (dotted camelCase, `^[a-z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*)+$`), an
optional `Raw` (boolean, number, string, string list, or ISO 8601 UTC date), `Source` and `AsOf`. A fact with the
same `Key` from the same `Source` replaces the earlier one. The shared keys are listed under "Fact keys" in
`website/docs/writing-tests/formatting-test-results.md`. The ones this design reads:

| Key | Raw | Used for |
| --- | --- | --- |
| `device.managed`, `device.compliant` | bool | The devices behind `intune.devices-compliant`. Management and compliance are separate facts |
| `device.joinType` | `AzureAd`, `ServerAd` or `Workplace` | Join coverage, for hybrid join and token protection |
| `device.os` | string | Which platforms need a compliance policy |
| `user.mfaRegistered`, `user.passwordless` | bool | The users behind `entra.mfa-registered` and the phishing-resistant steps |
| `user.privilegedRoles` | string list | The admins step of phishing-resistant MFA, and the privileged access goal |
| `signIn.daysSince` | int, or null when none is recorded | Leaving out stale devices and users. Counted from the fact's `AsOf`, not from now |

User facts are recorded under both the object ID and the UPN, so a record has them whichever way it was keyed.
The readiness checks write the same keys for the objects they list.

## 13. Keeping the catalogue current

The sources are the nine Learn mirrors built with `merill/learn-mirror`. They crawl Learn four times a day and
make one commit per changed page. They cover Entra, Intune, Defender, security (Zero Trust), Purview, Teams,
SharePoint, Exchange and Windows Server. The tooling lives in `build/steps/`:

| Script | Job |
| --- | --- |
| `Update-MtLearnMirror.ps1` | Clones or updates the mirrors into a cache folder, and builds a URL-to-file index. Old URLs are followed through Learn's redirects: 23 of the 77 Intune and Defender links in check guides are redirects today |
| `Find-MtStepCandidate.ps1` | For the Learn pages that check guides and catalogue sources link, pulls the prerequisite sections and sentences ("before you", "first", "must", "won't work without") with their file and line. Writes proposals as JSON for a maintainer, and optionally asks a model to reword them as `Note` text. Nothing enters the catalogue without review |
| `Test-MtStepSource.ps1` | For each source, lists the mirror commits to its file since `Reviewed`. Exits non-zero when any changed |

A scheduled workflow, `.github/workflows/step-sources.yaml`, runs `Test-MtStepSource.ps1` weekly and keeps one
issue open that lists the steps whose sources changed, with the diff link for each. It opens issues, never pull
requests. A maintainer re-reads the page and bumps `Reviewed`.

The unit tests make no network calls. They check that every `Url` is a well-formed Learn URL. Only the workflow
checks it against the mirrors.

## 14. Enforcement

`powershell/tests/general/StepCatalog.Tests.ps1`:

- every file matches the schema and has no unknown keys;
- step IDs are unique, their product key is in the taxonomy, and the file they are in is named after that key;
- every ID in `Requires`, `RequiresOneOf`, `RecommendedFirst`, `Conflicts` and a goal's `Step` exists;
- every `RequiresOneOf` group has at least two steps, and no step names the same step in two relationships;
- `Requires`, `RequiresOneOf` and `RecommendedFirst` together have no cycle, and the message names the cycle;
- every `OnlyWhen` key is a known condition;
- every step has a source, every `Note` is 200 characters or less, and maintainer-only sources are under 10%
  of all sources;
- every step belongs to at least one goal, and goal IDs are unique.

`Get-MtStepProblem` makes these checks, plus two about the tests: every `Step` that a built-in test or a
`packs/*/taxonomy.json` names exists, and (with `-Coverage`, over every built-in test) `Unchecked` is set exactly
on the steps that no test names. `./build/Build-MaesterModule.ps1` fails on all of them except the `Unchecked`
check, because the build can run on a folder that holds only some of the tests. A run only warns about a step
the catalogue does not have.

## 15. The first catalogue

This is a draft from the research, and Phase 1's expert pass (milestone M2) confirms every row against the
mirrors before any test is tagged. Three goals were checked against Learn: compliant devices, risk policies
and token protection. The other four come from known Microsoft guidance and still need the same check.

| Goal | Steps, in order | Verifying tests (draft) |
| --- | --- | --- |
| Foundation (under most goals) | `entra.emergency-access-excluded` · `entra.ca-exclude-sync-accounts` (only when `hybrid-identity`) | MT.1005, MT.1034 · MT.1020 |
| `compliant-devices` Require compliant devices | `intune.compliance-policies` → `intune.automatic-enrollment` (recommended first) → `intune.devices-compliant` → `intune.mark-unassigned-noncompliant` (recommended first) → `entra.ca-require-compliant-device`. `entra.ca-require-managed-device` needs one of `intune.devices-compliant` and `entra.hybrid-join` | ZTA.24541–24543, ZTA.24545, ZTA.24547 · ZTA.24546 · new check · MT.1054, CIS.M365.4.1 · MT.1001, ZTA.24824 · CIS.M365.5.2.2.9, CISA.MS.AAD.3.7, MT.1014 |
| `risk-policies` Risk-based Conditional Access | `entra.mfa-registered` → `entra.password-hash-sync` (only when hybrid, recommended first) → `entra.password-writeback` (only when hybrid) → `entra.remediate-risky-users` (recommended first) → `entra.ca-user-risk` and `entra.ca-sign-in-risk` → `entra.ca-risk-policies-separate` | new check · CIS.M365.5.1.8.1 · unchecked · MT.1260 · MT.1013, CIS.M365.5.2.2.6, CISA.MS.AAD.2.1 and MT.1012, CIS.M365.5.2.2.7, CISA.MS.AAD.2.3 · MT.1049 |
| `phishing-resistant-mfa` Phishing-resistant MFA | `entra.passkeys-enabled` and `entra.temporary-access-pass` → `entra.windows-hello` → `entra.phishing-resistant-registered` → `entra.phishing-resistant-admins` → `entra.phishing-resistant-all` | EIDSCA.AF01–AF06, ZTA.21839 · EIDSCA.AT01, AT02 · ZTA.24551 · ZTA.21782 (admins only) · CISA.MS.AAD.3.6, ZTA.21783, ZTA.21781 · CISA.MS.AAD.3.1, ASD.ISM-1872, ZTA.21784 |
| `privileged-access` Standing privilege to PIM | `entra.emergency-access-excluded` → `entra.pim-eligible-roles` → `entra.pim-alerts` → `entra.pim-roles-used` | MT.1025–MT.1028, MT.1031, ZTA.21816, ZTA.21876 · CISA.MS.AAD.7.7 · MT.1030 |
| `token-protection` Token protection | `entra.windows-devices-registered` → `entra.ca-token-protection` (rollout: report-only pilot) | unchecked: needs sign-in logs to see Windows sign-ins without a device identity · CIS.M365.5.2.2.16, ZTA.21941, ZTA.21786 |
| `email-authentication` Email authentication | `exchange.spf` and `exchange.dkim` → `exchange.dmarc-monitor` → `exchange.dmarc-enforce` | CIS.M365.2.1.8, CISA.MS.EXO.2.2, ORCA.235 · CIS.M365.2.1.9, CISA.MS.EXO.3.1, ORCA.108, ORCA.108.1 · CIS.M365.2.1.10, CISA.MS.EXO.4.1, 4.3 · CISA.MS.EXO.4.2, MT.1182 |
| `defender-device-risk` Defender risk in compliance | `defender.endpoint-onboarding` → `intune.defender-connector` → `intune.compliance-device-risk` (requires `intune.compliance-policies`) | ZTA.41045 · MT.1098, ZTA.24871 · MT.1216, MT.1231, MT.1235 |

That is 34 steps over about 75 existing tests, plus the two new checks. Expect most tests to name no step:
antivirus settings, sharing
settings and most EIDSCA values stand on their own. The value is concentrated where Conditional Access,
devices and authentication meet.

The first catalogue has no `Conflicts` entry yet. The obvious one is that Conditional Access policies need
security defaults turned off. MT.1021 can't verify it, because it checks that security defaults are on and
skips any tenant with Entra ID P1 or better, which is every tenant that uses Conditional Access. A readiness
check, "Security defaults are off where Conditional Access is licensed", would make the conflict checkable.
It is listed with the later checks in section 11.

Candidates for later goals come from the research: legacy authentication,
guest access, app consent, workload credentials, hybrid hardening, SSPR, LAPS, data protection, SharePoint
sharing, audit, Defender for Office 365, Global Secure Access, AI agents, Copilot readiness, Insider Risk,
Defender for Cloud Apps, third-party mail filters, Defender for Identity, Power Platform and Active Directory.

## 16. Delivery

| Milestone | Work | Needs |
| --- | --- | --- |
| M1 Format | Schema and loader (`Get-MtStepCatalog`, internal), the `Step` attribute in C#, the schema table and the reader, `StepCatalog.Tests.ps1`, and the compliant-devices goal as the fixture | This design |
| M2 Catalogue | Expert pass on the seven goals against the mirrors, then `Step` on about 75 tests, plus `Step` in the Zero Trust `taxonomy.json` | M1, and the instance-attribute change on `feat/zta-taxonomy-mapping` |
| M3 Engine | `Step` on rows, `Get-MtResultStep` (status, readiness, rank, scope), `LastKnown`, `-Step`, `-IncludePrerequisites`, `Get-MtTest -Step`, CSV and Markdown columns, the console line | M1 |
| M4 Report | Action plan groups and lanes, Before you fix this, rollout in How to fix, the overview card | M3's result shape. It can start on sample data once section 7 is final |
| M5 Readiness checks | The two checks of section 11 | M1 for `Step`. The checks can be written before it |
| M6 Tooling | `build/steps/` scripts and the weekly workflow | M1 |
| M7 Docs and site | `Step` in `website/docs/writing-tests/index.mdx`, a defender's path page, and one page per goal on maester.dev built by `prepare-data.mjs` | M2 |

Once M1 lands, M2, M5 and M6 touch different files and can run in parallel sessions. M3 and M4 follow in order.

## 17. Decisions

The owner accepted the recommended answer to each decision on 5 November 2026.

| # | Decision | Ruling | Alternatives considered |
| --- | --- | --- | --- |
| 1 | Name readers see | **Defender's path**, the counterpart of an attack path | "Implementation order", "Do this first" |
| 2 | Attribute name | **`Step`** | `Change` (clashes with the report's Changes page and with drift), `Prerequisite` (says the opposite of what most tests are) |
| 3 | What a lane is called | **Goal** (`Goals` in the result) | "Path", which clashes with `-Path` on `Invoke-Maester` and `Get-MtTest` and with file paths in the result |
| 4 | Where the catalogue lives | **`powershell/assets/steps/`**, beside the taxonomy, with no build change | A top-level `steps/` folder like `packs/`, which is easier to find but needs a build copy and a layout rule. Not under `tests/`, which holds only suites |
| 5 | Statuses | **Done, Not done, Unknown, Not checked, Not applicable** | Only Done and Not done, which turns every gap into a failure |
| 6 | Investigate | **Counts as Unknown** | Counts as Not done |
| 7 | Conflicts | **Block** while the conflicting step is on, declared on the step that needs the other off | Warn only |
| 8 | Selectors | **`-Step` and `-IncludePrerequisites`**, no goal selector, no new public command | A `Get-MtStep` command, which would add public API to keep |
| 9 | Packs and custom tests | **May name built-in steps.** Their own catalogues come later | Built-in tests only |
| 10 | Readiness thresholds | **A `MinimumShare` parameter, default 95** | A fixed threshold. A config key shared by all the readiness checks |
| 11 | Earlier statuses | **`LastKnown` per test, read only when a step in scope is Not checked** | The newest earlier run only, which says little after a one-check run |
| 12 | Catalogue wording | **Maester's own words and a link, 200 characters at most** | Quoting Learn |
| 13 | Mining output | **Proposals for review, and a weekly issue for changed sources** | A workflow that opens pull requests |
| 14 | Fact keys | **Ask the facts work for `Key` and a raw value before it ships** | Add them later. That breaks nothing, but costs more |
| 15 | Action plan | **The defender's path leads the page, with the ranked list below** | A separate page, which keeps today's plan unchanged but hides the strong point |

## 18. Not in this design

- The insights step (`Insight.<ID>.ps1`), attack scenarios, the most exposed identities and the reader profile.
  They are the rest of Phase 1 and get a design of their own. Steps are the same unit as the planned "fix once,
  close many" groups, so that work reuses this catalogue.
- Custom step catalogues for users and packs.
- Measured user impact from sign-in logs and report-only results. It would feed readiness later.
- Goals for GitHub, Azure DevOps and Active Directory. Until they exist, those runs look as they do today.
- A model that decides pass, fail, severity or order. Order comes from the catalogue, and every relationship
  cites its source.
