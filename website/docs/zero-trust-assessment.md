---
sidebar_label: Zero Trust Assessment
sidebar_position: 50
title: Zero Trust Assessment integration
description: How Maester loads a ZTA result bundle and runs 38 ZTA-aware tests on top of it.
---

# Zero Trust Assessment integration

Maester can load a **Zero Trust Assessment** (ZTA) result bundle and run 38
`MT.Zta.*` tests on top of it. The integration is **opt-in via a single
parameter** — `Invoke-Maester -ZtaResultsPath <path-or-uri>` — and is
byte-identical to upstream behaviour when the parameter is absent.

ZTA itself runs separately. It produces a comprehensive JSON + SQLite
(DuckDB) export of a tenant's posture across the four Zero Trust pillars
(Identity, Devices, Network, Data). Maester reads that captured bundle and
adds **gap-fill, compensating-control, and analytics tests** that ZTA itself
doesn't perform — for example:

- *"ZTA flagged users without phish-resistant MFA. Does CA actually enforce
  phish-resistant for a typical privileged sign-in right now?"* — answered
  via a live CA What-If simulation.
- *"What percentage of recent sign-ins were not gated by ANY CA policy?"* —
  answered via a streaming query over the `SignIn` table.
- *"Are any privileged accounts registered with phishable methods (SMS,
  voice, email, Authenticator-push)?"* — answered via a `RoleAssignment ⨝
  UserRegistrationDetails` join.

These are checks Maester core can't run because they need the ZTA evidence
to scope the question. They're checks ZTA can't run because it doesn't drive
live Graph (What-If) or apply a severity overlay.

The two tools compose.

## Architecture

```text
┌─────────────────────────────────────────────────────────────────────┐
│  ZeroTrustAssessment (separate run — workstation / pipeline)        │
│  └─► zt-export/                                                     │
│       ├─ ZeroTrustAssessmentReport.json   (Tests[], TestPillar)     │
│       ├─ manifest.json                    (tenantId, runStartTime)  │
│       ├─ db/zt.db                         (DuckDB — optional Tier 2)│
│       └─ <Table>/<Table>-N.json shards    (JSON shadow — Tier 1)    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Invoke-Maester -ZtaResultsPath <path>                              │
│                                                                     │
│   1. Import-MtZtaResult                                            │
│      - resolves source (local / blob URI / upkg://)                 │
│      - loads manifest, freshness, ZtaSettings, GlobalSettings       │
│      - populates $script:MtZtaContext                               │
│                                                                     │
│   2. Update-MtSeverityFromZta                                       │
│      - applies ZtaSettings.SeverityEscalationRules to TestSettings  │
│      - mutation happens BEFORE Pester discovery                     │
│                                                                     │
│   3. Invoke-Pester                                                  │
│      - the 38 MT.Zta.* tests under tests/Zta/ call Get-MtZta        │
│      - each test runs in Pester's Run phase (not Discovery)         │
│      - errors surface as Failed / Skipped rows, never crash         │
│                                                                     │
│   4. Build-MtZtaBundle                                              │
│      - compiles per-tenant analytics                                │
│      - attached to $results.ZtaBundle for HTML / JSON / MD          │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  MaesterReport.{html, json, md}                                     │
│  └─► ZTA tab renders bundle analytics (Tenant scale, Auth-method    │
│      posture, CA coverage, Applications/Devices/Privileged cards,   │
│      by-pillar chart) alongside the 38 MT.Zta.* test rows.          │
└─────────────────────────────────────────────────────────────────────┘
```

### Internal helpers

Six private functions support the public surface. They are not exported and should not be called directly by test code:

- `Read-MtZtaJsonExport` — Tier 1 reader; streams `<Table>/<Table>-N.json` shards from the bundle's `zt-export/` directory. Universal — no native binaries required. Always populated.
- `Read-MtZtaDatabase` — Tier 2 reader; opens `db/zt.db` read-only via `DuckDB.NET.Data`. Returns `$null` when the assemblies are not reachable so Tier 1 carries the load.
- `Initialize-MtZtaDuckDbAssembly` — loads `DuckDB.NET.Data` from the ZTA module's own `lib/` directory. Never falls back to Maester's `lib/` to preserve supply-chain isolation.
- `Resolve-MtZtaArtifact` — resolves a source string (local path, Azure Blob URI, or `upkg://` Universal Package reference) to a local bundle root directory, downloading and extracting as needed.
- `Test-MtZtaFreshness` — derives the bundle age from `manifest.runStartTime` → `Report.ExecutedAt` → `zt.db` file mtime (in priority order); clamps future timestamps to age 0.
- `Group-MtZtaFlaggedIdentity` — matches failed ZTA tests to `CategoryMappings` buckets via `Get-MtZtaCategoryForTest`; caps per-category user lists to `DataDrivenSettings.MaxUsersPerCategory`.

## Prerequisites

1. **A ZTA run output.** Install via
   `Install-Module ZeroTrustAssessment -Scope CurrentUser` and run
   `Invoke-ZeroTrustAssessment -OutputFolder <path>`. The folder you
   feed Maester is the `zt-export/` subdirectory.
2. **Maester 2.2 or later** (this integration). Earlier versions don't have
   `-ZtaResultsPath`.
3. **A live Graph connection** to the same tenant ZTA scanned — required by
   the CA What-If tests (`MT.Zta.1130/1131/1132/1181`) and by
   `Build-MtZtaBundle` for the live CA policies. Use `Connect-Maester` or
   `Connect-MgGraph` with the standard Maester scope set.

## Quick start

```powershell
Connect-Maester
Invoke-Maester -ZtaResultsPath ./zta-bundle -Path ./tests
```

Three accepted source patterns for `-ZtaResultsPath`:

| Pattern                                                            | Use case                                                      |
| ------------------------------------------------------------------ | ------------------------------------------------------------- |
| Local folder, `.tar.gz`, or `.zip`                                 | Workstation runs; CI artifacts downloaded into the build dir  |
| `https://<account>.blob.core.windows.net/...`                      | Cross-pipeline / cross-tenant via Azure Blob (SAS / WIF)      |
| `upkg://<org>/<project>/<feed>/<name>@<ver>`                       | Azure Artifacts Universal Package versioned distribution      |

## The four focus mechanisms

Custom tests under `tests/Zta/` use four mechanisms (often combined):

1. **Tag-based selection** — `Get-MtZtaRecommendedTag` returns a tag list
   derived from ZTA findings. Run `Invoke-Maester -Tag (Get-MtZtaRecommendedTag)`
   to focus only on pillars ZTA flagged.
2. **Conditional `It`** — gates inside the test body. Example: `MT.Zta.1101`
   skips when the Identity fail ratio is below `0.5` so guest-specific deep
   dives don't fire on a healthy tenant.
3. **Data-driven `-ForEach`** — `MT.Zta.1200/1201/1202/1203` group flagged
   identities by CategoryMappings bucket and assert quality dimensions
   (Pillar present, Group cap respected, every entry actionable) per
   bucket in a single test row each.
4. **Severity escalation** — `Update-MtSeverityFromZta` reads
   `ZtaSettings.SeverityEscalationRules` and mutates `TestSettings[]` before
   Pester discovery so a Medium test can be escalated to High when ZTA
   evidence justifies (e.g. Identity pillar Failed ≥ 5).

## Configuration

Add a `ZtaSettings` block to your `maester-config.json` (alongside the
existing `GlobalSettings` and `TestSettings`):

```jsonc
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      "breakglass1@contoso.onmicrosoft.com",
      "12345678-1234-1234-1234-123456789012",
      { "userPrincipalName": "breakglass2@contoso.onmicrosoft.com", "displayName": "Tier-0 emergency #2" }
    ]
  },
  "ZtaSettings": {
    "FreshnessDays": 14,
    "ExpectedTenantId": null,
    "FocusMechanisms": ["Tag", "Conditional", "DataDriven", "Severity"],
    "PillarTagMap": {
      "Identity": ["Identity", "EID", "MFA", "ConditionalAccess", "PIM"],
      "Devices":  ["Intune", "Device", "Compliance", "Defender"],
      "Network":  ["Network", "GlobalSecureAccess", "GSA"],
      "Data":     ["Exchange", "SharePoint", "Purview", "Sensitivity"]
    },
    "CategoryMappings": [
      { "Category": "IdentityPosture",     "MatchPillar": "Identity", "MaesterTagBoost": ["Identity","MFA"] },
      { "Category": "DevicePosture",       "MatchPillar": "Devices",  "MaesterTagBoost": ["Intune","Compliance"] },
      { "Category": "NetworkPosture",      "MatchPillar": "Network",  "MaesterTagBoost": ["Network","GSA"] },
      { "Category": "DataPosture",         "MatchPillar": "Data",     "MaesterTagBoost": ["Purview"] },
      { "Category": "PrivilegedAccess",    "MatchPillar": "*",        "MatchCategoryAny": ["Privileged access","Role management","Credential management"], "MaesterTagBoost": ["PIM"] },
      { "Category": "GuestUnconstrained",  "MatchPillar": "Identity", "MatchCategoryAny": ["External collaboration","External Identities","Guest"],         "MaesterTagBoost": ["Guest","B2B"] }
    ],
    "SeverityEscalationRules": [
      { "WhenPillarFailedAtLeast": 5, "Pillar": "Identity", "EscalateMaesterTagged": ["MFA","ConditionalAccess","PIM"], "From": "Medium", "To": "High" }
    ],
    "DataDrivenSettings": { "MaxUsersPerCategory": 50, "GroupSimilar": true },
    "Thresholds": {
      "MT.Zta.1001": 30, "MT.Zta.1002": 0.5, "MT.Zta.1003": 10,
      "MT.Zta.1004": 20, "MT.Zta.1005": 15, "MT.Zta.1006": 15,
      "MT.Zta.1102": 25, "MT.Zta.1104": 25, "MT.Zta.1133": 0,
      "MT.Zta.1140": 10, "MT.Zta.1140.NoMfa": 0, "MT.Zta.1140.Phishable": 5,
      "MT.Zta.1141": 1, "MT.Zta.1142": 1, "MT.Zta.1150": 5, "MT.Zta.1170": 25
    }
  }
}
```

`Get-MtMaesterConfig` is tenant-aware — drop a tenant-specific override at
`maester-config.<TenantId>.json` next to the default and it merges
automatically when Maester sees a matching `$env:AZURE_TENANT_ID` /
`Get-MgContext`.

## Test catalogue

Eleven files under `tests/Zta/`, 38 distinct test definitions. All severities
ride on Pester tags (`Severity:Low/Medium/High/Critical`).

### Pattern A — Always-on pillar posture

| ID | Title (excerpt) | Severity | Threshold key (default) |
| --- | --- | --- | --- |
| MT.Zta.1001 | Identity pillar fail count below warn threshold | High | `MT.Zta.1001` = 30 |
| MT.Zta.1002 | Identity fail ratio stays below 0.5 | High | `MT.Zta.1002` = 0.5 |
| MT.Zta.1003 | PrivilegedAccess bucket size below bar | High | `MT.Zta.1003` = 10 |
| MT.Zta.1004 | Devices pillar fail count | High | `MT.Zta.1004` = 20 |
| MT.Zta.1005 | Network pillar fail count | Medium | `MT.Zta.1005` = 15 |
| MT.Zta.1006 | Data pillar fail count | Medium | `MT.Zta.1006` = 15 |
| MT.Zta.1101 | Identity fail ratio high enough to deep-dive guests | Medium | gate at 0.5 |
| MT.Zta.1104 | Stale sign-in user count < threshold | High | `MT.Zta.1104` = 25 |
| MT.Zta.1107 | Zero permanent non-break-glass Global Administrator | Critical | n/a (boolean) |

### Pattern B — Gap-fill / compensating control

| ID | Trigger condition (ZTA) | Compensating control verified |
| --- | --- | --- |
| MT.Zta.1110 | `24543` / `24548` Failed | iOS App Protection covers unmanaged devices + assignment target valid |
| MT.Zta.1111 | `24547` / `24545` Failed | Android APP — same shape as 1110 |
| MT.Zta.1112 | `24547` / `24543` Failed | APP enforces `dataBackupBlocked=true` + `appActionIfDeviceComplianceRequired ∈ {wipe, block}` |
| MT.Zta.1130 | `21784` / `21801` Failed | CA What-If: typical user → grant requires MFA |
| MT.Zta.1131 | `21782` / `21783` Failed | CA What-If: privileged user → at least one in-scope auth strength is fully phish-resistant |
| MT.Zta.1132 | Identity pillar Failed ≥ 5 | CA What-If: legacy auth client → grant blocks |
| MT.Zta.1133 | always (gate: total sign-ins ≥ 100) | `SignIn.conditionalAccessStatus = 'notApplied'` rate stays below threshold (default 0%) |
| MT.Zta.1140 | `21801` / `21784` Failed | Members with no-MFA / phishable-only methods within sub-thresholds |
| MT.Zta.1141 | `21801` Failed AND 1140 has hits | At least *N* WHfB uplift candidates exist (else skip — needs strategic intervention) |
| MT.Zta.1142 | `21804` / `21784` Failed | At least *N* phishable-method users have a mobile device for Authenticator rollout (else skip) |
| MT.Zta.1143 | `21782` / `21804` Failed | Privileged accounts on phishable methods count |
| MT.Zta.1150 | `21858` / `21874` Failed | Inactive guests with active credentials within threshold |
| MT.Zta.1160 | `21992` / `21772` Failed | App credentials split by lifetime: never-expiring (Critical) + >1y (Medium) within budget |
| MT.Zta.1170 | Identity pillar Failed ≥ 5 | Stale non-privileged users count |
| MT.Zta.1180 | Devices pillar Failed ≥ 5 | Top compliance failure reasons enumerated for triage |
| MT.Zta.1181 | `24824` Failed | CA What-If: typical user on non-compliant device → grant blocks |

### Pattern C — Meta / operator

| ID | Purpose |
| --- | --- |
| MT.Zta.1010 | Bundle freshness within tolerance (warn-but-proceed) |
| MT.Zta.1102 | GuestUnconstrained bucket size below threshold |
| MT.Zta.1103 | Every GuestUnconstrained bucket entry has UPN/UserId/evidence |
| MT.Zta.1200 | Bucket family is populated (sentinel) |
| MT.Zta.1201 | Every populated bucket has a Pillar value |
| MT.Zta.1202 | Every bucket's Group sample size ≤ pre-cap Count |
| MT.Zta.1203 | Every bucket entry has UPN, UserId, or Evidence |
| MT.Zta.1301 | ZTA context is populated for this run |
| MT.Zta.1302 | `ZtaSettings` wired into context |
| MT.Zta.1303 | Each escalation rule has To severity and a selector |
| MT.Zta.1304 | No escalation rule lowers severity |
| MT.Zta.1305 | Severity overlay rule count + applied summary |
| MT.Zta.1402 | `Get-MtZtaRecommendedTag` produces a non-empty list |

## Pass / Fail / Skip semantics

Critical to triage — don't read Skipped as Passed-by-omission.

- **Passed** — the assertion held against actual data.
- **Failed** — the assertion did not hold; there is a real finding.
- **Skipped** — the test was not applicable for this tenant's current state:
  ZTA didn't flag the trigger (gap-fill N/A), too little data for
  statistical relevance, no eligible sample subject, or the ZTA context
  wasn't loaded.

The HTML report's right-hand sheet shows the `SkippedReason` text. A future
run with different ZTA findings may unskip a previously-skipped gap-fill.

## Joint reading with Maester core tests

Six ZTA tests have direct Maester core counterparts. Read them together to
avoid false comfort:

- **`MT.Zta.1107` + `MT.1032` / `CIS.M365.1.1.3` / `CISA.MS.AAD.7.1`** —
  GA count being acceptable doesn't mean GAs aren't permanent.
- **`MT.Zta.1140` + `CISA.MS.AAD.3.1` / `EIDSCA.AF*`** — phish-resistant CA
  policy existing doesn't mean users have registered phish-resistant methods.
- **`MT.Zta.1131` + `CISA.MS.AAD.3.6`** — policy state ≠ enforced state;
  What-If is the proof.
- **`MT.Zta.1133` + `MT.1003-1011` / `CISA.MS.AAD.1.1`** — policy-existence
  tests don't tell you whether sign-ins are actually covered.
- **`MT.Zta.1160` + `MT.1057` / `MT.1024.applicationCredentialExpiry`** —
  long-lived secrets warn-band vs. strict "no secrets at all" target.
- **`MT.Zta.1143` + `MT.Zta.1131` + `CISA.MS.AAD.3.6`** — registration
  inventory vs. live enforcement; both must align for end-to-end protection.

Each test's `## Related Maester core tests` section in the report walks
through the outcome matrix.

## Tier 1 / Tier 2 readers

`Import-MtZtaResult` exposes two readers via `Get-MtZta -Section Reader`:

- **Tier 1 (`Read-MtZtaJsonExport`)** — streams `<Table>/<Table>-N.json`
  shards. Universal — works on any PS host, air-gapped, Cloud Shell, no
  native binaries needed. **Always populated.**
- **Tier 2 (`Read-MtZtaDatabase`)** — opens `db/zt.db` read-only via
  `DuckDB.NET.Data` when the assemblies are reachable (probes: AppDomain →
  ZTA module's `lib/` → Maester's own `lib/`). When unreachable, returns
  `$null` and Tier 1 carries the load. No test today requires Tier 2; it's
  reserved for future joins / window-functions on multi-million-row tenants.

Both tiers expose the same surface: `Tables`, `GetRows`, `GetRow`, `Query`,
`BuildIndex`, `Dispose`.

## Freshness

`Import-MtZtaResult -ZtaFreshnessDays <int>` (default 14) controls the
freshness threshold. Older bundles still load (warn-but-proceed); the
context's `IsStale` flag rides the context so tests can decide what to do.
`MT.Zta.1010` is the warn-band gate test.

Timestamp source priority: `manifest.runStartTime` → `Report.ExecutedAt` →
`zt.db` file mtime.

## Cross-tenant safety

Pass `-ExpectedTenantId <guid>` to `Invoke-Maester` or
`Import-MtZtaResult`. The bundle's `manifest.tenantId` must match exactly
or the load aborts before any test runs. Pair with
`ZtaSettings.ExpectedTenantId` in config for the same effect set in code.

## Public cmdlet reference

All eight public cmdlets exported by the ZTA integration module:

| Cmdlet | Purpose |
| --- | --- |
| [`Import-MtZtaResult`](commands/Import-MtZtaResult.mdx) | Loads a ZTA result bundle (local / Blob / Universal Package) into `$script:MtZtaContext` |
| [`Get-MtZta`](commands/Get-MtZta.mdx) | Accessor for the loaded ZTA context; returns sections (Tests, Summary, FlaggedUsers, Reader, …) |
| [`Build-MtZtaBundle`](commands/Build-MtZtaBundle.mdx) | Compiles per-tenant analytics hashtable for injection into the Maester HTML/JSON report ZTA tab |
| [`Get-MtZtaRecommendedTag`](commands/Get-MtZtaRecommendedTag.mdx) | Derives a Pester `-Tag` list from ZTA failures so only relevant tests run |
| [`Get-MtZtaThreshold`](commands/Get-MtZtaThreshold.mdx) | Returns a per-test numeric threshold from `ZtaSettings.Thresholds` with a built-in default fallback |
| [`Update-MtSeverityFromZta`](commands/Update-MtSeverityFromZta.mdx) | Mutates a `TestSettings[]` array per `SeverityEscalationRules` before Pester discovery |
| [`Get-MtZtaAuthMethodSet`](commands/Get-MtZtaAuthMethodSet.mdx) | Returns the canonical PhishResistant / Phishable / SingleFactor method classification used by MFA-uplift tests |
| [`Test-MtZtaIsEmergencyAccess`](commands/Test-MtZtaIsEmergencyAccess.mdx) | Returns `$true` when a principalId or UPN matches the operator's declared break-glass list |

## Environment variables (Pester hand-off)

Two environment variables bridge the gap between the orchestrator's runspace and Pester's
child runspace. On ADO clean agents the sub-runspace reset never fires and these are never
read; on local PowerShell sessions with pre-loaded modules, Pester can spawn a child runspace
that resets `$script:` scope to null, making them load-bearing for cross-platform parity.

| Variable | Set by | Read by | Purpose |
| --- | --- | --- | --- |
| `$env:ZTA_RESULTS_REF` | `Invoke-Maester` after `Import-MtZtaResult` succeeds | `Get-MtZta` (self-heal path) | Holds the resolved local path of the ZTA bundle root so `Get-MtZta` can call `Import-MtZtaResult` again when it finds `$script:MtZtaContext` null in a Pester child runspace |
| `$env:MAESTER_ZTA_CONFIG_PATH` | `Invoke-Maester` after config is resolved | `Get-MtZta` (self-heal path) | Holds the resolved path of `maester-config.json` so the self-heal can re-read `ZtaSettings` and `GlobalSettings` — ensuring `CategoryMappings`, `SeverityEscalationRules`, and `EmergencyAccessAccounts` survive a sub-runspace reset |

## See also

- [`Invoke-Maester`](commands/Invoke-Maester.mdx) — primary entry, accepts `-ZtaResultsPath`
- [`Import-MtZtaResult`](commands/Import-MtZtaResult.mdx) — direct API
- [`Get-MtZta`](commands/Get-MtZta.mdx) — accessor for the loaded context
- [`Build-MtZtaBundle`](commands/Build-MtZtaBundle.mdx) — analytics bundle
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/) — upstream tool
