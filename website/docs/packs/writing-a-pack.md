---
title: Writing a pack
sidebar_position: 2
description: Create, check and publish a Maester Pack, with its manifest, tests, helpers and connector.
---

# Writing a pack

A pack is a folder with a `maester-pack.json`. Create one with `New-MtPack`:

```powershell
New-MtPack -Path ./maester-google-workspace -Id contoso.google-workspace -Code CNT -Connector
Test-MtPack ./maester-google-workspace
Invoke-MtTest -Path ./maester-google-workspace
```

`Invoke-MtTest -Path` runs the pack from its folder, with its helpers and connector, and reloads it on every call.
`Test-MtPack` runs every check `Install-MtPack` runs, without installing: use it in the pack's own CI.

```text
maester-google-workspace/
  maester-pack.json
  README.md
  tests/
    suite.json
    Test.MP.CNT.1001.ps1
    Test.MP.CNT.1001.md
  helpers/
    Get-CntWorkspaceSetting.ps1
  connector/
    Connect-CntGoogleWorkspace.ps1
```

To publish, push the folder to a GitHub repository owned by the publisher and create a release. A release made
[immutable](https://docs.github.com/repositories/releasing-projects-on-github/about-releases) starts its
cooldown when it is published; any other release starts it when each user first sees it.

## The manifest

```json
{
  "$schema": "https://maester.dev/schemas/maester-pack-1.0.json",
  "Id": "contoso.google-workspace",
  "Name": "Google Workspace checks",
  "Description": "Checks the security settings of a Google Workspace tenant.",
  "Version": "1.2.0",
  "Publisher": "contoso",
  "License": "MIT",
  "RequiresMaester": ">=3.1 <4.0",
  "Code": "CNT",
  "Suites": ["tests"],
  "Helpers": ["helpers"],
  "Connectors": [
    {
      "Service": "CNT.GoogleWorkspace",
      "DisplayName": "Google Workspace",
      "File": "connector/Connect-CntGoogleWorkspace.ps1",
      "Connect": "Connect-CntGoogleWorkspace",
      "Test": "Test-CntGoogleWorkspace",
      "Disconnect": "Disconnect-CntGoogleWorkspace"
    }
  ],
  "Uses": {
    "Services": ["CNT.GoogleWorkspace"],
    "GraphScopes": [],
    "TenantWrites": [],
    "Network": ["admin.googleapis.com", "oauth2.googleapis.com"],
    "Modules": [ { "Name": "GoogleWorkspaceTools", "Version": "1.4.2" } ]
  }
}
```

| Key | Content |
| --- | --- |
| `$schema` | `https://maester.dev/schemas/maester-pack-1.0.json`, so editors such as VS Code check the manifest as you type. Maester checks it again when the pack is installed and loaded. |
| `Id` | `<publisher>.<name>` in lower case. The publisher is the GitHub user or organisation that owns the repository; a pack whose publisher is not the repository owner is refused. |
| `Guid` | The pack's GUID. `New-MtPack` writes one. Keep it when you rename or move the pack: it is how the [pack registry](./registry.md) knows the pack. |
| `Version` | A semantic version, such as `1.2.0`. |
| `RequiresMaester` | The Maester versions the pack works with, such as `>=3.1 <4.0`. A pack that needs a newer Maester reports `RequiresNewerMaester`. `New-MtPack` fills in the version you made the pack with. |
| `Code` | The start of every test ID of the pack: `CNT` gives `MP.CNT.1001`. Two to ten letters or digits, starting with a letter. A publisher with several packs can group them with up to three parts separated by dots, such as `CNT.GWS` for `MP.CNT.GWS.1001`. No two installed packs may share a code, or have one code that starts with the other (`CNT` and `CNT.GWS`), so `Install-MtPack` refuses the second one. To own a code for good, [register it](./registry.md). A first part that looks like Maester's suites, Microsoft products or well-known brands is reserved. |
| `Suites` | Folders of native tests. Each needs a `suite.json` whose `Id` is the code or starts with it, such as `CNT.GoogleWorkspace`. |
| `Helpers` | Folders of `.ps1` files that hold functions the tests call. |
| `Connectors` | Services the pack connects to (below). |
| `Uses` | What the pack reaches, shown when it is installed. An unknown key under `Uses` is an error, so a pack cannot hide what it reaches behind a key an older Maester does not show. |
| `Uses.Modules` | PowerShell Gallery modules, each pinned to one exact `Version`. Maester saves them into its own store and checks their files before every load. A module the user installs themselves can only be run in a separate process: `{ "Name": "X", "MinimumVersion": "2.0.0", "Install": "User", "Process": "Child" }`. |
| `Requires.Packs` | Other packs this one needs: `{ "Id": "contoso.base", "Source": "contoso/maester-base", "Version": ">=1.0" }`. They are installed first, with their own approval. |
| `Exports` | Functions of this pack that packs requiring it may call. |
| `Pricing` | `Free` (the default) or `Paid`, for a pack that needs a paid product or subscription to be useful. The pack index shows it; Maester does not act on it. |
| `Banner` | An image in the pack that the pack index shows when it features the pack. See [Banner image](#banner-image). |
| `EnabledByDefault` | For a pack that ships with Maester: `false` to leave it off until the config turns it on. |

## Banner image

A banner is optional. When the maintainers feature a pack on [packs.maester.cloud](https://packs.maester.cloud), the
card shows the banner beside the pack's description; without one, the card shows the pack's code and name on a dark
background.

- **File:** `.png`, `.jpg` or `.webp`, at most 1 MB, inside the pack, for example `"Banner": "assets/banner.png"`.
  The index reads the type from the file's contents, not its name, and SVG is refused. A banner that fails these
  checks is left out and the card falls back to the code and name.
- **Size:** 1200 × 630 pixels (the 1.91:1 shape of a social preview). Another size is cropped to fill that shape.
- **Shown small:** about 600 pixels wide on a desktop and 340 on a phone. Use at most eight words of text, set large,
  and keep it away from the edges.
- **Your own brand.** Use another company's logo only for a pack built on that company's product, and only with its
  permission. Don't add words such as "Official" or "Verified": the index shows its own badges, and a banner that
  suggests an endorsement it doesn't have can get the pack removed.
- **No secrets or real data:** a screenshot must not show a real tenant, user or key.

### Making one with an AI image tool

Any image tool that takes a text prompt can make a banner. Image tools often misspell words, so check every letter,
or ask for an image with no text and add the title yourself in an editor. Fill in the parts in angle brackets:

```text
A wide banner image, 1200 x 630 pixels, for a software add-on called "<pack name>".
It checks the security settings of <service, for example Google Workspace> for IT administrators.
Style: clean, modern, flat illustration on a <dark navy / deep teal / near-black> gradient background,
with a simple abstract motif suggesting <what the pack checks, for example identity, email, devices>.
Text: the title "<pack name>" in large, bold, white sans-serif letters on the left,
and the line "<one short phrase, at most six words>" below it in smaller letters.
Leave a margin of at least 60 pixels on every side. No other text, no logos, no people,
no photos of screens, no badges or seals.
```

For an image without text, replace the `Text:` line with `No text at all; leave the left half plain for a title.`

## Tests and helpers

A pack's tests are [native tests](../writing-tests/index.mdx) with IDs `MP.<Code>.<n>`, or `MP.<Code>` for a family whose instances add their own part. (Packs that ship with
Maester are part of it and drop the `MP.`: the Zero Trust Assessment pack's tests are `ZTA.<n>`.) Every `.ps1` in a suite
or helper folder holds only functions: code outside a function is refused, because it would run while the pack
loads. A pack loads into a private module of its own, so its tests can call its helpers and Maester's exported
commands. One pack does not see another pack's functions unless it requires that pack and the pack lists them in
`Exports`. This keeps cooperating packs from colliding; it is not a security boundary, because code in the same
PowerShell process can reach anything in it (see [Pack security](./security.md)).

The scan flags, and raises the risk of, what a reviewer should look at: binary files, dynamic code
(`Invoke-Expression`, `[scriptblock]::Create`), starting processes, requests to hosts that `Uses.Network` does not
list, and module imports that `Uses.Modules` does not list.

## Showing a long-running test's output and progress

A test that runs a tool for a long time, such as an assessment in another PowerShell process, can show the person
running Maester what the tool is doing while it runs. In the full-screen dashboard both go into a box in the main
column; in the compact layout, CI and redirected output they are written to the console, indented.

- `Write-MtTestOutput` shows the tool's log. `-Title` opens the box, each line
  scrolls into it, `-Progress` pins a changing line at the bottom, and `-Complete` closes it (Maester closes it when
  the test ends).
- `Write-MtTestProgress` shows where the tool is, as a header at the top of
  the box: the stage (`-Stage`, `-StageNumber`, `-StageCount`), a bar of the items done (`-Completed`, `-Total`,
  `-Failed`, `-Running`), what it is working on (`-Current`, `-Status`), and the errors it reported
  (`-ErrorMessage`), which the box also counts. With `-Stages` (the names of all the stages) the stages are drawn
  as a track, like the phases of a Maester run. With `-Items` (each with `Id`, and optionally `Title`, `Status`,
  `Detail` and `Seconds`) the box lists the items running and those that finished, with their result and time,
  the way the dashboard lists Maester's own tests; outside the dashboard each finished item is written once. Each
  call replaces the progress before it, so pass everything you know each time; a call with only `-ErrorMessage`
  keeps the progress.

```powershell
Write-MtTestOutput -Title 'Collecting the tenant data'
Write-MtTestProgress -Stage 'Exporting' -StageNumber 1 -StageCount 3 -Completed 12 -Total 40 -Running 2 -Current 'Users', 'Groups'
Write-MtTestProgress -ErrorMessage 'The export of Devices failed: Forbidden'
```

A tool in another process does not need to call Maester to report its progress. Pipe its output to
`Write-MtTestOutput`, and have it write lines of this form to standard output, from any language:

```text
##maester[progress] {"stages":["Export","Tests","Report"],"stageNumber":1,"stage":"Exporting","completed":12,"total":40,"failed":1,"items":[{"id":"Users","detail":"page 3","seconds":12},{"id":"Groups","status":"Passed","seconds":4.2}]}
##maester[error] The export of Devices failed: Forbidden
```

These lines set the header instead of showing in the log. The JSON object takes the names of the parameters of
`Write-MtTestProgress` in any case (`error` for `-ErrorMessage`), and leaves out what it does not know. Write a
`progress` line when something changes (at most a few times a second): each one is drawn. A line that cannot be read is dropped.

The [Zero Trust Assessment pack](./zero-trust-assessment.md) is a worked example: its child process reads the
progress the assessment keeps and the progress logs it writes, once a second, and writes these lines (see
`Invoke-MtZtaCollection` in `packs/zero-trust-assessment/tests/Test.ZTA.ps1`).

## Connectors

A connector adds a service to Maester. Its file holds a `Connect` and a `Test` function, and optionally
`Disconnect`, `Renew` and `Describe`:

```powershell
function Connect-CntGoogleWorkspace {
    [CmdletBinding()]
    param([string] $Domain, [string] $CredentialPath)

    $token = Get-CntAccessToken -Domain $Domain -CredentialPath $CredentialPath
    Set-MtConnectionState -Value @{ Token = $token.AccessToken; ExpiresOn = $token.ExpiresOn } -Tenant $Domain
}

function Test-CntGoogleWorkspace {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    [bool](Get-MtConnectionState)
}
```

- `Connect-Maester -Service CNT.GoogleWorkspace` calls `Connect` with the parameters it has from `-ServiceSetting`,
  `MAESTER_CNT_GOOGLEWORKSPACE_<PARAMETER>` and `Connections.CNT.GoogleWorkspace` in the config.
- `Set-MtConnectionState` keeps what the tests need for the PowerShell session only; `Get-MtConnectionState`
  reads it back in a test or helper. A pack can read its own connection and those of packs it requires, never
  another pack's.
- `Test` decides whether the tests that need the service run. With `ExpiresOn` in the state, Maester calls `Renew`
  shortly before it expires.
- The service name is `<Code>.<Name>`. Tests declare it like any service: `Service = 'CNT.GoogleWorkspace'`.
  `"OptIn": true` makes its tests not run, rather than skipped, while it is not connected.
