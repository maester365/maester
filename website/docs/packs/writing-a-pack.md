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
| `Id` | `<publisher>.<name>` in lower case. The publisher is the GitHub user or organisation that owns the repository; a pack whose publisher is not the repository owner is refused. |
| `Version` | A semantic version, such as `1.2.0`. |
| `RequiresMaester` | The Maester versions the pack works with, such as `>=3.1 <4.0`. A pack that needs a newer Maester reports `RequiresNewerMaester`. |
| `Code` | Two to five letters or digits, the start of every test ID of the publisher: `MP.CNT.1001`. Use one code for all your packs. Codes that look like Maester's suites, Microsoft products or well-known brands are reserved. |
| `Suites` | Folders of native tests. Each needs a `suite.json` whose `Id` is the code or starts with it, such as `CNT.GoogleWorkspace`. |
| `Helpers` | Folders of `.ps1` files that hold functions the tests call. |
| `Connectors` | Services the pack connects to (below). |
| `Uses` | What the pack reaches, shown when it is installed. An unknown key under `Uses` is an error, so a pack cannot hide what it reaches behind a key an older Maester does not show. |
| `Uses.Modules` | PowerShell Gallery modules, each pinned to one exact `Version`. Maester saves them into its own store and checks their files before every load. A module the user installs themselves can only be run in a separate process: `{ "Name": "X", "MinimumVersion": "2.0.0", "Install": "User", "Process": "Child" }`. |
| `Requires.Packs` | Other packs this one needs: `{ "Id": "contoso.base", "Source": "contoso/maester-base", "Version": ">=1.0" }`. They are installed first, with their own approval. |
| `Exports` | Functions of this pack that packs requiring it may call. |
| `Pricing` | `Free` (the default) or `Paid`, for a pack that needs a paid product or subscription to be useful. The pack index shows it; Maester does not act on it. |
| `Banner` | An image in the pack (`.png`, `.jpg` or `.webp`, at most 1 MB, 1200 × 630 pixels works best) that the pack index can show when it features the pack. |
| `EnabledByDefault` | For a pack that ships with Maester: `false` to leave it off until the config turns it on. |

## Tests and helpers

A pack's tests are [native tests](../writing-tests/index.mdx) with IDs `MP.<Code>.<n>`. Every `.ps1` in a suite
or helper folder holds only functions: code outside a function is refused, because it would run while the pack
loads. A pack loads into a private module of its own, so its tests can call its helpers and Maester's exported
commands. One pack does not see another pack's functions unless it requires that pack and the pack lists them in
`Exports`. This keeps cooperating packs from colliding; it is not a security boundary, because code in the same
PowerShell process can reach anything in it (see [Pack security](./security.md)).

The scan flags, and raises the risk of, what a reviewer should look at: binary files, dynamic code
(`Invoke-Expression`, `[scriptblock]::Create`), starting processes, requests to hosts that `Uses.Network` does not
list, and module imports that `Uses.Modules` does not list.

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
