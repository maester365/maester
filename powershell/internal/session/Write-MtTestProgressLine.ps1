function Write-MtTestProgressLine {
    <#
    .SYNOPSIS
    Passes a line of the ##maester protocol to Write-MtTestProgress, and says whether the line was one.

    .DESCRIPTION
    Write-MtTestOutput calls this for each line it is given. A tool in another process reports its progress by
    writing one of these lines to its output:

        ##maester[progress] {"stage":"Exporting","stageNumber":1,"stageCount":3,"completed":4,"total":9}
        ##maester[error] The export of Users failed

    The JSON object takes the names of the parameters of Write-MtTestProgress in any case, and "error" for
    -ErrorMessage. A line of the protocol that cannot be read is dropped, not shown: it is not meant for people.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Line
    )

    if ($Line -notmatch '^\s*##maester\[(progress|error)\]\s?(.*)$') { return $false }
    $kind = $Matches[1].ToLowerInvariant()
    $body = $Matches[2].Trim()
    try {
        if ($kind -eq 'error') {
            if ($body) { Write-MtTestProgress -ErrorMessage $body }
            return $true
        }
        $data = $body | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($data -isnot [System.Collections.IDictionary]) { throw 'The progress is not a JSON object.' }
        $names = @{
            stage = 'Stage'; stagenumber = 'StageNumber'; stagecount = 'StageCount'; completed = 'Completed'
            total = 'Total'; failed = 'Failed'; running = 'Running'; current = 'Current'; status = 'Status'
            error = 'ErrorMessage'; errormessage = 'ErrorMessage'
        }
        $splat = @{}
        foreach ($key in $data.Keys) {
            $name = $names[([string]$key).ToLowerInvariant()]
            if (-not $name -or $null -eq $data[$key]) { continue }
            $value = $data[$key]
            $splat[$name] = switch ($name) {
                { $_ -in 'Current', 'ErrorMessage' } { [string[]]@($value | ForEach-Object { [string]$_ }) }
                { $_ -in 'Stage', 'Status' } { [string]$value }
                default { [int]$value }
            }
        }
        if ($splat.Count -gt 0) { Write-MtTestProgress @splat }
    } catch {
        Write-Debug "A line of progress could not be read: $_"
    }
    return $true
}
