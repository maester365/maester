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

$actions | Sort-Object Action, Label | Format-Table Action, Label, From -AutoSize | Out-String | Write-Host
if ($unmanaged.Count -gt 0) { Write-Host "Not in $(Split-Path $Path -Leaf), left unchanged: $($unmanaged -join ', ')" }

if (-not $Apply) {
    Write-Host 'Dry run. Run again with -Apply to make these changes.'
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
    Write-Host "$($action.Action): $($e.name)"
}

foreach ($action in ($actions | Where-Object Action -EQ 'Merge')) {
    # Pull requests and issues carrying the old label; discussions are labelled through GraphQL.
    $numbers = Invoke-Gh @('api', "repos/$Repository/issues?labels=$(Get-EncodedLabel $action.From)&state=all&per_page=100", '--paginate', '--jq', '.[].number')
    foreach ($number in $numbers) {
        Invoke-Gh @('api', "repos/$Repository/issues/$number/labels", '-X', 'POST', '-f', "labels[]=$($action.Label)") | Out-Null
    }
    $owner, $name = $Repository -split '/', 2
    $query = 'query($owner:String!,$name:String!,$label:String!){repository(owner:$owner,name:$name){label(name:$label){discussions(first:100){nodes{id}}} newLabel:label(name:"' + $action.Label.Replace('"', '\"') + '"){id}}}'
    $result = Invoke-Gh @('api', 'graphql', '-f', "query=$query", '-f', "owner=$owner", '-f', "name=$name", '-f', "label=$($action.From)") | ConvertFrom-Json
    $newLabelId = $result.data.repository.newLabel.id
    foreach ($discussion in $result.data.repository.label.discussions.nodes) {
        $mutation = 'mutation($id:ID!,$label:ID!){addLabelsToLabelable(input:{labelableId:$id,labelIds:[$label]}){clientMutationId}}'
        Invoke-Gh @('api', 'graphql', '-f', "query=$mutation", '-f', "id=$($discussion.id)", '-f', "label=$newLabelId") | Out-Null
    }
    Write-Host "Merged $($action.From) into $($action.Label) ($(@($numbers).Count) PRs and issues, $(@($result.data.repository.label.discussions.nodes).Count) discussions)"
    if ($DeleteMerged) {
        Invoke-Gh @('api', "repos/$Repository/labels/$(Get-EncodedLabel $action.From)", '-X', 'DELETE') | Out-Null
        Write-Host "Deleted $($action.From)"
    }
}
