<#
.SYNOPSIS
Checks the Maester Pack registry: every publisher and pack GUID, pack ID, pack code and publisher name is unique.

.DESCRIPTION
The registry (pack-registry/publishers/<publisher>.json, one file per publisher) records who owns a pack code. Each
file holds the publisher's GUID, its GitHub name, its display name, the GitHub accounts that own the entry (login
and numeric ID, which survives a rename) and its packs, each with its own GUID, pack ID, code and repository.

The script returns one line for each problem it finds, and nothing when the registry is valid:

- a file that is not JSON, has a key the registry does not know, or misses a required value;
- a file whose name is not its Publisher;
- a GUID that is not a GUID, or that appears twice anywhere in the registry (publishers and packs share one space);
- two publishers with the same Publisher or Name;
- a pack ID that does not start with its publisher, or that is registered twice;
- a code that is not a valid pack code, whose first part is reserved, or that overlaps another registered code
  (equal, or one is the other followed by more parts, such as CNT and CNT.GWS);
- a pack that ships with Maester (packs/<name>/maester-pack.json) that is not registered under maester365 with the
  same ID, code and GUID.

Reserved names and code overlap use the same rules as Install-MtPack, so the module is imported from -Root.

.PARAMETER Root
The repository root. Defaults to the root of the repository this script is in.

.PARAMETER Path
The registry folder that holds publishers/. Defaults to pack-registry under -Root.

.EXAMPLE
./build/packs/Test-MtPackRegistry.ps1

Lists every problem in the registry. The unit test powershell/tests/general/PackRegistry.Tests.ps1 fails when
there is one.
#>
[CmdletBinding()]
[OutputType([string])]
param(
    [string] $Root = (Resolve-Path "$PSScriptRoot/../..").Path,
    [string] $Path
)

if (-not $Path) { $Path = Join-Path $Root 'pack-registry' }
if (-not (Get-Module Maester)) { Import-Module (Join-Path $Root 'powershell/Maester.psd1') -ErrorAction Stop }
$maester = Get-Module Maester

$problems = [System.Collections.Generic.List[string]]::new()
$guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
$codePattern = '^[A-Za-z][A-Za-z0-9]{1,9}(\.[A-Za-z][A-Za-z0-9]{1,9}){0,2}$'
$publisherKeys = @('$schema', 'Guid', 'Publisher', 'Name', 'Owners', 'Packs')
$ownerKeys = @('Login', 'Id')
$packKeys = @('Guid', 'Id', 'Code', 'Repository')

$guids = @{}
$publishers = @{}
$names = @{}
$packIds = @{}
$codes = [System.Collections.Generic.List[object]]::new()

$claimGuid = {
    param($value, $what, $file)
    if (-not ($value -is [string] -and $value -match $guidPattern)) {
        $problems.Add("${file}: $what Guid '$value' is not a GUID.")
        return
    }
    $key = $value.ToLowerInvariant()
    if ($guids.ContainsKey($key)) { $problems.Add("${file}: $what Guid '$value' is already used by $($guids[$key]).") }
    else { $guids[$key] = "$what in $file" }
}
$checkKeys = {
    param($object, $allowed, $what, $file)
    foreach ($p in $object.PSObject.Properties) {
        if ($p.Name -notin $allowed) { $problems.Add("${file}: $what has the key '$($p.Name)', which the registry does not know.") }
    }
}

$folder = Join-Path $Path 'publishers'
$files = @(if (Test-Path -LiteralPath $folder) { Get-ChildItem -LiteralPath $folder -File | Sort-Object Name })
foreach ($item in $files) {
    $file = "publishers/$($item.Name)"
    if ($item.Extension -ne '.json') { $problems.Add("${file}: only <publisher>.json files belong in publishers/."); continue }
    try { $entry = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { $problems.Add("${file}: is not valid JSON: $($_.Exception.Message)"); continue }
    if ($entry -isnot [pscustomobject]) { $problems.Add("${file}: must hold one JSON object."); continue }
    & $checkKeys $entry $publisherKeys 'The publisher' $file

    # The publisher is the GitHub user or organisation in each of its pack IDs, so it follows the pack ID's rules.
    $publisher = [string]$entry.Publisher
    if ($publisher -cnotmatch '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$') {
        $problems.Add("${file}: Publisher must be the GitHub user or organisation in lower case; it is '$publisher'.")
    } elseif ($item.BaseName -cne $publisher) {
        $problems.Add("${file}: the file must be named after its Publisher: publishers/$publisher.json.")
    } elseif ($publishers.ContainsKey($publisher)) {
        $problems.Add("${file}: the publisher '$publisher' is already registered in $($publishers[$publisher]).")
    } else { $publishers[$publisher] = $file }

    & $claimGuid $entry.Guid "The publisher" $file

    $name = [string]$entry.Name
    if (-not $name.Trim()) { $problems.Add("${file}: Name is required.") }
    elseif ($names.ContainsKey($name.Trim().ToLowerInvariant())) { $problems.Add("${file}: the Name '$name' is already used by $($names[$name.Trim().ToLowerInvariant()]).") }
    else { $names[$name.Trim().ToLowerInvariant()] = $file }

    # The GitHub accounts that may change this entry. The numeric ID stays the same when an account is renamed.
    $owners = @($entry.Owners | Where-Object { $null -ne $_ })
    if ($owners.Count -eq 0) { $problems.Add("${file}: Owners must list at least one GitHub account, with its Login and numeric Id.") }
    $ownerIds = @{}
    foreach ($owner in $owners) {
        & $checkKeys $owner $ownerKeys 'An owner' $file
        if ([string]$owner.Login -notmatch '^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$') { $problems.Add("${file}: the owner Login '$($owner.Login)' is not a GitHub login.") }
        if (-not ($owner.Id -is [long] -or $owner.Id -is [int]) -or $owner.Id -le 0) { $problems.Add("${file}: the owner '$($owner.Login)' needs its numeric GitHub Id, such as 1288081.") }
        elseif ($ownerIds.ContainsKey($owner.Id)) { $problems.Add("${file}: the owner Id $($owner.Id) is listed twice.") }
        else { $ownerIds[$owner.Id] = $true }
    }

    # Packs of the maester365 organisation have IDs that start with maester.
    $prefix = if ($publisher -eq 'maester365') { 'maester.' } else { "$publisher." }
    foreach ($pack in @($entry.Packs | Where-Object { $null -ne $_ })) {
        & $checkKeys $pack $packKeys 'A pack' $file
        $id = [string]$pack.Id
        $what = if ($id) { "The pack $id" } else { 'A pack' }
        if ($id -cnotmatch '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?\.[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$') {
            $problems.Add("${file}: the pack Id '$id' must be '<publisher>.<name>' in lower case.")
        } elseif (-not $id.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            $problems.Add("${file}: the pack Id '$id' must start with '$prefix'.")
        } elseif ($packIds.ContainsKey($id)) {
            $problems.Add("${file}: the pack Id '$id' is already registered in $($packIds[$id]).")
        } else { $packIds[$id] = $file }

        & $claimGuid $pack.Guid $what $file

        $code = [string]$pack.Code
        if ($code -cnotmatch $codePattern -or $code -cne $code.ToUpperInvariant()) {
            $problems.Add("${file}: $what has the Code '$code'; a code is one to three parts in upper case separated by dots, each two to ten letters or digits starting with a letter, such as ZTA or CNT.GWS.")
        } else {
            $reserved = & $maester { param($c, $o) Test-MtPackReservedName -Code $c -Official:$o } $code ($publisher -eq 'maester365')
            if ($reserved) { $problems.Add("${file}: ${what}: $reserved") }
            foreach ($other in $codes) {
                if (& $maester { param($a, $b) Test-MtPackCodeOverlap -Code $a -Other $b } $code $other.Code) {
                    $problems.Add("${file}: $what has the Code '$code', which overlaps the code '$($other.Code)' of $($other.Id) in $($other.File).")
                }
            }
            $codes.Add([pscustomobject]@{ Code = $code; Id = $id; Guid = [string]$pack.Guid; File = $file; Publisher = $publisher })
        }

        if ([string]$pack.Repository -notmatch '^https://github\.com/[A-Za-z0-9-]+/[A-Za-z0-9._-]+/?$') {
            $problems.Add("${file}: $what needs its Repository, such as https://github.com/$publisher/<repository>.")
        }
    }
}

# The packs that ship with Maester take their codes first, so each one must be registered as it is.
$builtIn = Join-Path $Root 'packs'
foreach ($manifestFile in @(if (Test-Path -LiteralPath $builtIn) { Get-ChildItem -LiteralPath $builtIn -Directory | ForEach-Object { Join-Path $_.FullName 'maester-pack.json' } | Where-Object { Test-Path -LiteralPath $_ } })) {
    $where = "packs/$(Split-Path (Split-Path $manifestFile -Parent) -Leaf)/maester-pack.json"
    try { $manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { $problems.Add("${where}: is not valid JSON."); continue }
    $registered = $codes | Where-Object { $_.Id -eq $manifest.Id } | Select-Object -First 1
    if (-not $registered -or $registered.Publisher -ne 'maester365') {
        $problems.Add("${where}: the pack $($manifest.Id) ships with Maester, so it must be registered in publishers/maester365.json.")
        continue
    }
    if ([string]$manifest.Code -ne $registered.Code) { $problems.Add("${where}: the Code is '$($manifest.Code)', but the registry has '$($registered.Code)'.") }
    if ([string]$manifest.Guid -ne $registered.Guid) { $problems.Add("${where}: the Guid is '$($manifest.Guid)', but the registry has '$($registered.Guid)'.") }
}

$problems
