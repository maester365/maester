<#
.SYNOPSIS
    Makes the repository's labels match .github/labels.json.

.DESCRIPTION
    Reads the label list in .github/labels.json and compares it with the labels on the repository.
    For each entry it creates the label, updates its colour and description, or renames an old label
    listed in 'renamedFrom'. Renaming keeps the label on every pull request, issue and discussion
    that has it. When more than one old label maps to the same new one, the first is renamed and the
    items carrying the others get the new label too. The old labels are only deleted with
    -DeleteMerged.

    Without -Apply the script only prints what it would do. Labels that are not in the file are
    listed and never changed.

    Requires the GitHub CLI (gh), signed in with permission to manage labels on the repository.

.PARAMETER Repository
    The repository as owner/name. Defaults to maester365/maester.

.PARAMETER Path
    The label file. Defaults to .github/labels.json in this repository.

.PARAMETER Apply
    Make the changes. Without it, the script prints the plan and changes nothing.

.PARAMETER DeleteMerged
    With -Apply, delete an old label once its items carry the new one.

.EXAMPLE
    ./build/github/Sync-GitHubLabels.ps1

    Prints the changes that would make the repository's labels match .github/labels.json.

.EXAMPLE
    ./build/github/Sync-GitHubLabels.ps1 -Apply

    Creates, renames and updates the labels.
#>
[CmdletBinding()]
param(
    [string] $Repository = 'maester365/maester',
    [string] $Path = (Join-Path $PSScriptRoot '../../.github/labels.json'),
    [switch] $Apply,
    [switch] $DeleteMerged
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

function Invoke-Gh {
    param([Parameter(Mandatory)] [string[]] $Arguments)
    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw "gh $($Arguments -join ' ') failed with exit code $LASTEXITCODE." }
    $output
}

function Get-EncodedLabel([string] $Name) { [uri]::EscapeDataString($Name) }

$wanted = (Get-Content -Path $Path -Raw | ConvertFrom-Json).labels
$existing = @{}
foreach ($label in (Invoke-Gh @('api', "repos/$Repository/labels", '--paginate', '--jq', '.[] | @json') | ForEach-Object { $_ | ConvertFrom-Json })) {
    $existing[$label.name.ToLowerInvariant()] = $label
}

$actions = [System.Collections.Generic.List[object]]::new()
$claimed = [System.Collections.Generic.HashSet[string]]::new()

foreach ($entry in $wanted) {
    $key = $entry.name.ToLowerInvariant()
    [void]$claimed.Add($key)
    $oldNames = @($entry.renamedFrom | Where-Object { $_ -and $existing.ContainsKey($_.ToLowerInvariant()) })
    foreach ($old in $entry.renamedFrom) { if ($old) { [void]$claimed.Add($old.ToLowerInvariant()) } }

    if ($existing.ContainsKey($key)) {
        $current = $existing[$key]
        if ($current.color -ne $entry.color -or $current.description -ne $entry.description -or $current.name -cne $entry.name) {
            $actions.Add([pscustomobject]@{ Action = 'Update'; Label = $entry.name; From = $current.name; Entry = $entry })
        }
        foreach ($old in $oldNames) {
            $actions.Add([pscustomobject]@{ Action = 'Merge'; Label = $entry.name; From = $existing[$old.ToLowerInvariant()].name; Entry = $entry })
        }
    } elseif ($oldNames.Count -gt 0) {
        $actions.Add([pscustomobject]@{ Action = 'Rename'; Label = $entry.name; From = $existing[$oldNames[0].ToLowerInvariant()].name; Entry = $entry })
        foreach ($old in ($oldNames | Select-Object -Skip 1)) {
            $actions.Add([pscustomobject]@{ Action = 'Merge'; Label = $entry.name; From = $existing[$old.ToLowerInvariant()].name; Entry = $entry })
        }
    } else {
        $actions.Add([pscustomobject]@{ Action = 'Create'; Label = $entry.name; From = ''; Entry = $entry })
    }
}

$unmanaged = @($existing.Values | Where-Object { -not $claimed.Contains($_.name.ToLowerInvariant()) } | ForEach-Object name)

$actions | Sort-Object Action, Label | Format-Table Action, Label, From -AutoSize | Out-String | Write-Information
if ($unmanaged.Count -gt 0) { Write-Information "Not in $(Split-Path $Path -Leaf), left unchanged: $($unmanaged -join ', ')" }

if (-not $Apply) {
    Write-Information 'Dry run. Run again with -Apply to make these changes.'
    return
}

# Renames and updates first, so merges find the new label in place.
foreach ($action in ($actions | Where-Object Action -in 'Rename', 'Update', 'Create')) {
    $e = $action.Entry
    switch ($action.Action) {
        'Create' {
            Invoke-Gh @('api', "repos/$Repository/labels", '-X', 'POST', '-f', "name=$($e.name)", '-f', "color=$($e.color)", '-f', "description=$($e.description)") | Out-Null
        }
        default {
            Invoke-Gh @('api', "repos/$Repository/labels/$(Get-EncodedLabel $action.From)", '-X', 'PATCH', '-f', "new_name=$($e.name)", '-f', "color=$($e.color)", '-f', "description=$($e.description)") | Out-Null
        }
    }
    Write-Information "$($action.Action): $($e.name)"
}

foreach ($action in ($actions | Where-Object Action -EQ 'Merge')) {
    # Pull requests and issues carrying the old label; discussions are labelled through GraphQL.
    $numbers = Invoke-Gh @('api', "repos/$Repository/issues?labels=$(Get-EncodedLabel $action.From)&state=all&per_page=100", '--paginate', '--jq', '.[].number')
    foreach ($number in $numbers) {
        Invoke-Gh @('api', "repos/$Repository/issues/$number/labels", '-X', 'POST', '-f', "labels[]=$($action.Label)") | Out-Null
    }
    # Discussions carrying the old label, found through search (labels have no discussions connection).
    $labelId = Invoke-Gh @('api', "repos/$Repository/labels/$(Get-EncodedLabel $action.Label)", '--jq', '.node_id')
    $search = 'query($q:String!,$after:String){search(type:DISCUSSION,query:$q,first:100,after:$after){discussionCount pageInfo{hasNextPage endCursor} nodes{... on Discussion{id}}}}'
    $discussions = [System.Collections.Generic.List[string]]::new()
    $discussionCount = 0
    $after = $null
    do {
        $arguments = @('api', 'graphql', '-f', "query=$search", '-f', "q=repo:$Repository label:`"$($action.From)`"")
        if ($after) { $arguments += @('-f', "after=$after") }
        $page = (Invoke-Gh $arguments | ConvertFrom-Json).data.search
        $discussionCount = [int]$page.discussionCount
        foreach ($node in $page.nodes) { if ($node.id) { $discussions.Add($node.id) } }
        $after = $page.pageInfo.endCursor
    } while ($page.pageInfo.hasNextPage)
    foreach ($id in $discussions) {
        $mutation = 'mutation($id:ID!,$label:ID!){addLabelsToLabelable(input:{labelableId:$id,labelIds:[$label]}){clientMutationId}}'
        Invoke-Gh @('api', 'graphql', '-f', "query=$mutation", '-f', "id=$id", '-f', "label=$labelId") | Out-Null
    }
    Write-Information "Merged $($action.From) into $($action.Label) ($(@($numbers).Count) PRs and issues, $($discussions.Count) discussions)"
    # Search returns at most 1,000 results. If it found fewer discussions than it counted, some still
    # carry only the old label, so deleting it would drop their label.
    if ($DeleteMerged -and $discussions.Count -lt $discussionCount) {
        Write-Warning "Kept $($action.From): search found $($discussions.Count) of $discussionCount discussions carrying it. Relabel the rest, then run again with -DeleteMerged."
    } elseif ($DeleteMerged) {
        Invoke-Gh @('api', "repos/$Repository/labels/$(Get-EncodedLabel $action.From)", '-X', 'DELETE') | Out-Null
        Write-Information "Deleted $($action.From)"
    }
}
