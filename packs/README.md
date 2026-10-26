# Maester Packs that ship with Maester

Each folder here is a [Maester Pack](https://maester.dev/docs/packs) that is part of the Maester module:
a `maester-pack.json`, its suites of native tests, and its helpers and connectors.

- The build copies this folder to `packs/` in the module. A pack loads into its own private module from
  its folder; it is not compiled into `Maester.psm1`.
- A pack here is trusted as the module is: it needs no lock entry and no approval. It runs when its
  manifest says `"EnabledByDefault": true` unless the Maester config turns it off with
  `Packs: [{ "Id": "<id>", "Enabled": false }]`, and the other way round.
- Its ID is `maester.<name>`. Its `Code` is its own, such as `ZTA`. Because it is part of Maester, its test IDs
  have no `MP.` prefix: they are `ZTA.<n>` (or `ZTA` for a family), and its suite IDs start with `ZTA`. The code
  is added to the reserved prefixes in `powershell/assets/MaesterTestSchema.psd1`, so custom tests cannot use it. A pack installed later may not take a code that overlaps it. Its rows in the results have `Source = Custom` and a `Package`, so they never count as
  Maester's own checks.
- PowerShell Gallery modules it declares in `Uses.Modules` are pinned to one version. Users save them with
  `Install-MtPack <id>`, which records each module's digest in `maester-packs.lock.json`.

Check a pack with `Test-MtPack ./packs/<name> -Official` and run its tests with `Invoke-MtTest -Path ./packs/<name>`.
