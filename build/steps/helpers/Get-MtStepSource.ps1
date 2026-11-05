function Get-MtStepSource {
    <#
    .SYNOPSIS
    Lists the sources of every step in the step catalogue.

    .DESCRIPTION
    Reads the step files of the defender's path catalogue (powershell/assets/steps/<product>.json; goals.json and the
    schema hold no sources) and returns one object per source with Step, StepTitle, File, Index (the source's
    position in the step's Sources, from 1), Url, Mirror, Maintainer, Note and Reviewed (yyyy-MM-dd).

    The catalogue is read as JSON and not validated: Get-MtStepCatalog and StepCatalog.Tests.ps1 do that. A file
    that is not valid JSON stops the script, so a broken catalogue is never reported as unchanged.

    .PARAMETER Path
    The catalogue folder.

    .EXAMPLE
    Get-MtStepSource -Path ./powershell/assets/steps | Where-Object Url
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "The step catalogue folder '$Path' does not exist." }
    $files = Get-ChildItem -LiteralPath $Path -Filter '*.json' -File | Where-Object Name -NotIn 'goals.json', 'steps.schema.json' | Sort-Object Name
    foreach ($file in $files) {
        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } catch {
            throw "$($file.Name) is not valid JSON: $($_.Exception.Message)"
        }
        foreach ($step in @($content['Steps'])) {
            if ($step -isnot [System.Collections.IDictionary]) { continue }
            $index = 0
            foreach ($source in @($step['Sources'])) {
                if ($source -isnot [System.Collections.IDictionary]) { continue }
                $index++
                $reviewed = $source['Reviewed']
                if ($reviewed -is [datetime]) { $reviewed = $reviewed.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) }
                [pscustomobject][ordered]@{
                    Step       = [string] $step['Id']
                    StepTitle  = [string] $step['Title']
                    File       = $file.Name
                    Index      = $index
                    Url        = if ($source['Url']) { [string] $source['Url'] } else { $null }
                    Mirror     = if ($source['Mirror']) { [string] $source['Mirror'] } else { $null }
                    Maintainer = if ($source['Maintainer']) { [string] $source['Maintainer'] } else { $null }
                    Note       = [string] $source['Note']
                    Reviewed   = if ($reviewed) { [string] $reviewed } else { $null }
                }
            }
        }
    }
}
