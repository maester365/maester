function ConvertTo-MtZtaWorkshopTask {
    <#
    .SYNOPSIS
    Returns a workshop task in the shape the report's Zero Trust plan view reads, without empty values.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # A task of a pillar file, or an extra task of maester.json.
        [Parameter(Mandatory)] $Task,

        # 'workshop' or 'maester'.
        [Parameter(Mandatory)] [string] $Origin,

        # The task's checks, each with Id, Source and, for a same check, Via.
        [Parameter()] [AllowEmptyCollection()] [object[]] $Checks = @(),

        # Maester's note on the task.
        [Parameter()] [AllowNull()] $Note
    )

    $row = [ordered]@{ Id = [string]$Task.Id }
    foreach ($name in 'Name', 'AreaId', 'Swimlane', 'Phase', 'Priority', 'Effort', 'UserImpact', 'License', 'Cisa') {
        $row[$name] = Get-MtZtaWorkshopValue $Task $name
    }
    $row.Dependencies = @(Get-MtZtaWorkshopValue $Task 'Dependencies' | Where-Object { $_ } | ForEach-Object { [string]$_ })
    $row.Icon = Get-MtZtaWorkshopValue $Task 'Icon'
    $row.Doc = Get-MtZtaWorkshopValue $Task 'Doc'
    $row.Note = $Note
    $row.Origin = $Origin
    $row.Checks = @($Checks)
    foreach ($key in @($row.Keys)) {
        if ($row[$key] -isnot [array] -and [string]::IsNullOrEmpty([string]$row[$key])) { $row.Remove($key) }
    }
    [pscustomobject]$row
}
