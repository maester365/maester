<#
.SYNOPSIS
Regenerates powershell/assets/MaesterAttackTechniques.json from one MITRE ATT&CK Enterprise release.

.DESCRIPTION
The Mitre attribute of a test lists ATT&CK technique IDs. They are validated against one pinned release, whose
version is recorded in powershell/assets/MaesterTaxonomy.psd1 (Attack.Version). This script downloads that
release's STIX bundle from https://github.com/mitre-attack/attack-stix-data and writes a trimmed copy: tactic
and technique IDs and names, the tactics of each technique, and the IDs the release has revoked or deprecated.

To move the pin: change Attack.Version in the taxonomy, run this script, then run the unit tests. A test that
names a technique the new release retired fails NativeTestAttributes.Tests.ps1 until its Mitre list is updated.

.PARAMETER Version
The ATT&CK Enterprise version, for example 19.2. Defaults to Attack.Version in the taxonomy.

.PARAMETER StixPath
A local copy of enterprise-attack-<version>.json. When omitted the bundle is downloaded.

.EXAMPLE
./build/attack/Update-MtAttackTechniques.ps1

.EXAMPLE
./build/attack/Update-MtAttackTechniques.ps1 -Version 20.0
#>
[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+$')]
    [string] $Version,

    [string] $StixPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$assets = Join-Path $repoRoot 'powershell/assets'
if (-not $Version) {
    $Version = (Import-PowerShellDataFile -LiteralPath (Join-Path $assets 'MaesterTaxonomy.psd1')).Attack.Version
}

$downloaded = $false
if (-not $StixPath) {
    $StixPath = Join-Path ([System.IO.Path]::GetTempPath()) "enterprise-attack-$Version.json"
    $uri = "https://raw.githubusercontent.com/mitre-attack/attack-stix-data/master/enterprise-attack/enterprise-attack-$Version.json"
    Write-Information "Downloading $uri" -InformationAction Continue
    Invoke-WebRequest -Uri $uri -OutFile $StixPath
    $downloaded = $true
}

$bundle = Get-Content -LiteralPath $StixPath -Raw | ConvertFrom-Json -Depth 30
if ($downloaded) { Remove-Item -LiteralPath $StixPath -ErrorAction SilentlyContinue }

function Get-MtAttackId {
    param($Object)
    $reference = @($Object.external_references) | Where-Object { $_.source_name -eq 'mitre-attack' } | Select-Object -First 1
    if ($reference) { $reference.external_id }
}

function Test-MtAttackFlag {
    param($Object, [string] $Name)
    $property = $Object.PSObject.Properties[$Name]
    [bool] ($property -and $property.Value)
}

# Tactics by their short name, which is how a technique's kill chain phases refer to them.
$tacticByShortName = @{}
$modified = [datetime]::MinValue
foreach ($object in $bundle.objects) {
    if ($object.type -eq 'x-mitre-tactic') {
        $tacticByShortName[$object.x_mitre_shortname] = [pscustomobject]@{ Id = Get-MtAttackId $object; Name = $object.name }
    }
    if ($object.type -eq 'x-mitre-collection') { $modified = [datetime] $object.modified }
}

$techniques = [System.Collections.Generic.List[object]]::new()
$retired = [System.Collections.Generic.List[string]]::new()
foreach ($object in $bundle.objects) {
    if ($object.type -ne 'attack-pattern') { continue }
    $id = Get-MtAttackId $object
    if (-not $id) { continue }
    if ((Test-MtAttackFlag $object 'revoked') -or (Test-MtAttackFlag $object 'x_mitre_deprecated')) {
        $retired.Add($id)
        continue
    }
    $tactics = @($object.kill_chain_phases | Where-Object { $_.kill_chain_name -eq 'mitre-attack' } |
            ForEach-Object { $tacticByShortName[$_.phase_name].Id } | Where-Object { $_ })
    $techniques.Add([pscustomobject]@{ Id = $id; Name = $object.name; Tactics = $tactics })
}

# One line per tactic and technique keeps the diff of a version bump readable.
$quote = { param($text) ($text | ConvertTo-Json -Compress) }
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('{')
$lines.Add(' "Source": "MITRE ATT&CK Enterprise",')
$lines.Add(" `"Version`": $(& $quote $Version),")
$lines.Add(" `"Modified`": $(& $quote $modified.ToUniversalTime().ToString('yyyy-MM-dd')),")
$lines.Add(" `"Url`": $(& $quote "https://attack.mitre.org/versions/v$($Version.Split('.')[0])/"),")
$lines.Add(" `"License`": $(& $quote "(c) $($modified.Year) The MITRE Corporation. This work is reproduced and distributed with the permission of The MITRE Corporation. MITRE ATT&CK is licensed under the terms at https://attack.mitre.org/resources/legal-and-branding/terms-of-use/."),")
$lines.Add(' "Note": "Trimmed copy: technique and tactic identifiers and names only. Regenerate with build/attack/Update-MtAttackTechniques.ps1 when the pinned version changes.",')
$lines.Add(' "Tactics": [')
$tacticLines = $tacticByShortName.Values | Sort-Object Id | ForEach-Object { "  {`"Id`": $(& $quote $_.Id), `"Name`": $(& $quote $_.Name)}" }
$lines.Add(($tacticLines -join ",`n"))
$lines.Add(' ],')
$lines.Add(' "Techniques": [')
$techniqueLines = $techniques | Sort-Object Id | ForEach-Object {
    "  {`"Id`": $(& $quote $_.Id), `"Name`": $(& $quote $_.Name), `"Tactics`": [$(($_.Tactics | ForEach-Object { & $quote $_ }) -join ', ')]}"
}
$lines.Add(($techniqueLines -join ",`n"))
$lines.Add(' ],')
$lines.Add(' "Retired": [')
$lines.Add((($retired | Sort-Object -Unique | ForEach-Object { "  $(& $quote $_)" }) -join ",`n"))
$lines.Add(' ]')
$lines.Add('}')

$target = Join-Path $assets 'MaesterAttackTechniques.json'
[System.IO.File]::WriteAllText($target, (($lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
$null = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json -Depth 6 # fails loudly if the file is not valid JSON
Write-Information "Wrote $target (ATT&CK $Version): $($techniques.Count) techniques, $($tacticByShortName.Count) tactics, $(@($retired | Sort-Object -Unique).Count) retired IDs." -InformationAction Continue
