function Get-MtResultFramework {
    <#
    .SYNOPSIS
    Builds the Frameworks list of a result: the catalogue of each framework the rows map to.

    .DESCRIPTION
    A row names requirements through Benchmark and Control, but a report also needs the requirements that no
    test checks and a framework's name, version and size, so that it can show coverage. For each framework
    key the rows use, this returns Key, Name, Version, Url, Complete and Requirements.

    - A framework that ships with Maester (Get-MtBuiltInFramework) lists every requirement with its facts
      (Level, Profile, Criticality, Strategy, Guideline, Section and so on), without Related and Tests. A
      catalogue larger than -MaxRequirements (the ISM) lists only the requirements the rows name, and
      Complete is $false.
    - NIST SP 800-53 (assets/MaesterNistControls.json) lists only the controls the rows name, with Title and
      Family, and Complete is $false: a run is never meant to cover the whole catalogue.
    - A framework key that neither knows (one declared by a custom suite) has no entry.

    Frameworks are listed in the order Maester ships them, then NIST.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Result rows with Benchmark and Control.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $InputObject = @(),

        # The largest catalogue that is listed in full.
        [Parameter()] [int] $MaxRequirements = 300
    )

    $ignoreCase = [System.StringComparer]::OrdinalIgnoreCase
    # Framework key to the requirement IDs the rows name.
    $used = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.HashSet[string]]]::new($ignoreCase)
    $add = {
        param($key, $id)
        if (-not $key -or -not $id) { return }
        if (-not $used.ContainsKey($key)) { $used[$key] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal) }
        $null = $used[$key].Add($id)
    }
    foreach ($row in $InputObject) {
        if ($null -eq $row) { continue }
        if ($row.PSObject.Properties['Benchmark'] -and $row.Benchmark -and $row.Benchmark.Framework) {
            & $add ([string]$row.Benchmark.Framework) ([string]$row.Benchmark.Requirement)
        }
        if ($row.PSObject.Properties['Control']) {
            foreach ($reference in @($row.Control | Where-Object { $_ })) {
                $key, $id = ([string]$reference) -split ':', 2
                & $add $key $id
            }
        }
    }
    if ($used.Count -eq 0) { return }

    foreach ($framework in @(Get-MtBuiltInFramework)) {
        if (-not $framework.IsValid -or -not $used.ContainsKey($framework.Key)) { continue }
        $complete = @($framework.Requirements).Count -le $MaxRequirements
        $requirements = @(foreach ($requirement in $framework.Requirements) {
                if (-not $complete -and -not $used[$framework.Key].Contains([string]$requirement.Id)) { continue }
                $entry = [ordered]@{ Id = [string]$requirement.Id }
                foreach ($fact in $requirement.PSObject.Properties) {
                    if ($fact.Name -in 'Id', 'Related', 'Tests') { continue }
                    $entry[$fact.Name] = $fact.Value
                }
                [pscustomobject]$entry
            })
        [pscustomobject][ordered]@{
            Key          = $framework.Key
            Name         = $framework.Name
            Version      = $framework.Version
            Url          = $framework.Url
            Complete     = $complete
            Requirements = $requirements
        }
    }

    $nistKey = 'nist-800-53-r5'
    if ($used.ContainsKey($nistKey)) {
        $nist = Get-MtNistControlCatalog
        if ($nist) {
            [pscustomobject][ordered]@{
                Key          = $nistKey
                Name         = [string]$nist.Name
                Version      = [string]$nist.Version
                Url          = 'https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final'
                Complete     = $false
                Requirements = @(foreach ($control in $nist.Controls) {
                        if ($used[$nistKey].Contains([string]$control.Id)) { [pscustomobject][ordered]@{ Id = [string]$control.Id; Title = $control.Title; Family = $control.Family } }
                    })
            }
        }
    }
}
