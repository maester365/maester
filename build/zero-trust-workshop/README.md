# Zero Trust Workshop data for the Zero Trust plan

The Zero Trust Assessment pack ([`packs/zero-trust-assessment`](../../packs/zero-trust-assessment)) adds the
Microsoft Zero Trust Workshop plan to the Maester report, where the **Zero Trust plan** view shows each workshop
task with the status of the checks that measure it. The data is in the pack's `workshop` folder.

| File | What it holds | Kept by |
| --- | --- | --- |
| `identity.json`, `devices.json`, `data.json`, `network.json`, `infrastructure.json`, `security-operations.json`, `ai.json` | One pillar each: its functional areas and tasks (swimlane, phase, priority, effort, user impact, licence, CISA maturity stage, dependencies), each task's guidance and the assessment tests Microsoft maps to it (`Checks`, as `ZTA.<id>`) | `Update-MtZtWorkshopData.ps1` |
| `icons.json` | The SVG icons the tasks and areas use | `Update-MtZtWorkshopData.ps1` |
| `maester.json` | Maester's additions: Maester tests that measure a workshop task, a note per task, and tasks the workshop does not have | Hand |

## Where the data comes from

- Pillars, areas and tasks: `https://zerotrust.microsoft.com/data/<pillar>-pillar-data.json`. Tasks the workshop
  hides are left out.
- Icons: `https://zerotrust.microsoft.com/icons/<name>`.
- Guidance: `src/react/docs/workshop-guidance/` in
  [microsoft/zerotrustassessment](https://github.com/microsoft/zerotrustassessment) (MIT licence), the document the
  task's link names. Front matter, embedded videos, the title and the effort and impact lines are removed.
- Check mapping: `src/powershell/assets/ztw-task-mapping.json` in the same repository (MIT licence), assessment
  test ID to workshop task IDs.

Zero Trust Workshop content © Microsoft; guidance and check mapping from microsoft/zerotrustassessment, MIT licence.

## Refresh the generated files

```powershell
./build/zero-trust-workshop/Update-MtZtWorkshopData.ps1
```

It takes a few minutes (one request per guidance document). Set `GITHUB_TOKEN` if the GitHub API limits you. The
output is stable: a pillar keeps its `Updated` date unless something else in it changed, so a rerun on unchanged
sources leaves no diff. The script warns about a mapped task no pillar shows and an icon the site does not have.
Run `./powershell/tests/pester.ps1` afterwards: `ZeroTrustWorkshopPlan.Tests.ps1` checks that `maester.json` still
resolves against the new files.

## Add Maester tests to a task

Edit `maester.json`. Under `Tasks`, key by the workshop task ID and list the built-in tests that measure it:

```json
"Tasks": {
  "RMI_001": { "Tests": ["MT.1003", "MT.1004"], "Note": "Maester also checks that the policy set has no gaps." }
}
```

These are added after Microsoft's mapping, never instead of it. A built-in test that `taxonomy.json` lists in
`AlsoCheckedBy` for one of the task's assessment tests is added on its own, as the same check, so it does not
need to be listed here. `Note` is optional and shown on the task.

A task the workshop does not have goes under `ExtraTasks`, with its `Pillar` (one of the pillar IDs above), an
`Id` that starts with `MAE_`, the `AreaId` of an area of that pillar (as the pillar file spells it), the same
fields as a workshop task, its `Tests`, and its guidance as Markdown in `Doc`.

The unit tests fail when `maester.json` names a test, task, area or dependency that does not exist.

## What the report receives

At run time `Add-MtZtaWorkshopPlan` (in the pack's `helpers`) builds one JSON document with
`Get-MtZtaWorkshopPlan` and attaches it to the report with
`Add-MtReportAttachment -Name 'zero-trust-workshop' -ContentType 'application/json'`. Its schema is
`maester.zero-trust-workshop/1`: the seven pillars, each task with its checks (`Source` is `microsoft`,
`same-check` with `Via` naming the assessment test, or `maester`), and only the icons the plan uses. Set
`ZeroTrustAssessment.WorkshopPlan` to `false` to leave it out.
