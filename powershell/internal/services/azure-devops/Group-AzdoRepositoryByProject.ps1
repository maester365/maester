function Group-AzdoRepositoryByProject {
    <#
    .SYNOPSIS
    Groups Advanced Security repository enablement entries by project name, largest group first.

    .DESCRIPTION
    The Advanced Security org enablement API returns each repository as a projectId and repositoryId GUID with no
    names. This resolves the project GUIDs with a single Get-ADOPSProject call and groups the supplied entries by
    project name, so a result table can report where the gaps are instead of listing GUIDs.

    Groups are ordered by descending count, then by project name, so the largest gap appears first. A project
    whose name cannot be resolved falls back to its GUID rather than being dropped.

    .EXAMPLE
    Group-AzdoRepositoryByProject -Repository $Unenrolled

    Returns Group-Object output with Name set to the project name and Count set to the number of supplied
    repositories in that project.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.PowerShell.Commands.GroupInfo])]
    param(
        # Repository enablement entries, each carrying a projectId property.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Repository
    )

    $ProjectNames = @{}
    try {
        Get-ADOPSProject | ForEach-Object { $ProjectNames[$_.id] = $_.name }
    } catch {
        Write-Verbose "Failed to resolve Azure DevOps project names: $($_.Exception.Message)"
    }

    $Repository | ForEach-Object {
        if ($ProjectNames.ContainsKey($_.projectId)) { $ProjectNames[$_.projectId] } else { $_.projectId }
    } | Group-Object | Sort-Object -Property @{Expression = 'Count'; Descending = $true }, @{Expression = 'Name'; Descending = $false }
}
