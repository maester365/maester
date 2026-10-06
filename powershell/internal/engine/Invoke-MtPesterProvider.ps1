function Invoke-MtPesterProvider {
    <#
    .SYNOPSIS
    Runs the Pester-format tests of a run with one Invoke-Pester call (design section 8).

    .DESCRIPTION
    Pester is not a dependency of Maester 3.0. It is imported here, and only when the run has Pester-format
    tests, with a minimum version of 5.7.1 so the Pester 3.4 that ships with Windows PowerShell is never
    used. When no suitable Pester is installed, the result is Unavailable and the caller reports each
    statically known Pester test as an Error row with reason PesterNotAvailable.

    The configuration is the caller's -PesterConfiguration (a PesterConfiguration object or a hashtable)
    or a new one, with the engine's filter applied on top: run paths and exclusions, tags, excluded lines,
    PassThru, Verbosity, and Run.Parallel / Run.FailOnNullOrEmptyForEach forced off where they exist.
    Returns Results (the Pester result object), Configuration and Unavailable.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Paths, exclusions, tags, excluded lines and switches decided by the engine.
        [Parameter(Mandatory)] [pscustomobject] $Filter,

        # The caller's -PesterConfiguration, if any.
        [Parameter()] [AllowNull()] [object] $Configuration,

        [Parameter()] [string] $Verbosity = 'None'
    )

    if (-not (Import-MtPester)) {
        return [pscustomobject]@{ Results = $null; Configuration = $null; Unavailable = $true }
    }

    $config = New-MtPesterConfiguration -Configuration $Configuration
    $config.Run.PassThru = $true
    $config.Output.Verbosity = $Verbosity
    $config.Run.Path = @($Filter.RunPath)
    if (@($Filter.ExcludePath).Count -gt 0) {
        # Appended, never replaced: a caller's Run.ExcludePath still applies.
        $config.Run.ExcludePath = @(@($config.Run.ExcludePath.Value) + @($Filter.ExcludePath) | Where-Object { $_ })
    }
    if (@($Filter.ExcludeLine).Count -gt 0) {
        $config.Filter.ExcludeLine = @(@($config.Filter.ExcludeLine.Value) + @($Filter.ExcludeLine) | Where-Object { $_ })
    }
    $config.Filter.Tag = @($Filter.Tag | Where-Object { $_ })
    $config.Filter.ExcludeTag = @($Filter.ExcludeTag | Where-Object { $_ })
    if ($Filter.SkipRun) { $config.Run.SkipRun = $true }
    # Maester writes the CI test-result file for native and Pester rows together (appendix A.2).
    if ($Filter.DisableTestResult) { $config.TestResult.Enabled = $false }
    # Pester 6 options that would lose Maester's result details or fail discovery of an empty -ForEach.
    if ($config.Run.PSObject.Properties['Parallel']) { $config.Run.Parallel = $false }
    if ($config.Run.PSObject.Properties['FailOnNullOrEmptyForEach']) { $config.Run.FailOnNullOrEmptyForEach = $false }

    $results = Invoke-Pester -Configuration $config
    [pscustomobject]@{ Results = $results; Configuration = $config; Unavailable = $false }
}

function Import-MtPester {
    <#
    .SYNOPSIS
    Makes Pester 5.7.1 or later available. Returns $false when it is not installed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $minimum = [version]'5.7.1'
    if (Get-Module -Name Pester | Where-Object { $_.Version -ge $minimum }) { return $true }
    $available = Get-Module -Name Pester -ListAvailable -ErrorAction SilentlyContinue | Where-Object { $_.Version -ge $minimum } |
        Sort-Object Version -Descending | Select-Object -First 1
    if (-not $available) { return $false }
    try {
        Import-Module -Name $available.Path -Global -ErrorAction Stop -WarningAction SilentlyContinue
        $true
    } catch {
        Write-Verbose "Pester could not be imported: $($_.Exception.Message)"
        $false
    }
}

function New-MtPesterConfiguration {
    <#
    .SYNOPSIS
    Returns a PesterConfiguration from the caller's -PesterConfiguration (object or hashtable), or a new one.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()] [AllowNull()] [object] $Configuration
    )

    if ($null -eq $Configuration) { return New-PesterConfiguration }
    if ($Configuration.GetType().FullName -eq 'PesterConfiguration') { return $Configuration }
    if ($Configuration -is [System.Collections.IDictionary]) { return New-PesterConfiguration -Hashtable $Configuration }
    throw '-PesterConfiguration must be a PesterConfiguration object or a hashtable.'
}

function Get-MtPesterOption {
    <#
    .SYNOPSIS
    Reads an option such as 'Filter.Tag' from a -PesterConfiguration object or hashtable, without needing Pester.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()] [AllowNull()] [object] $Configuration,
        [Parameter(Mandatory)] [string] $Name
    )

    if ($null -eq $Configuration) { return $null }
    $section, $key = $Name -split '\.', 2
    $sectionValue = if ($Configuration -is [System.Collections.IDictionary]) { $Configuration[$section] } else { $Configuration.$section }
    if ($null -eq $sectionValue) { return $null }
    $option = if ($sectionValue -is [System.Collections.IDictionary]) { $sectionValue[$key] } else { $sectionValue.$key }
    if ($null -ne $option -and $option.PSObject.Properties['Value'] -and $option.PSObject.Properties['Default']) { return $option.Value }
    $option
}

function New-MtPesterUnavailableRow {
    <#
    .SYNOPSIS
    Creates the Error row (reason PesterNotAvailable) for a Pester-format test that could not run.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # A row from Get-MtPesterFileInventory.
        [Parameter(Mandatory)] [object] $InventoryRow,
        [Parameter()] [AllowNull()] [object] $Origin
    )

    $id = if ($InventoryRow.Id) { $InventoryRow.Id } else { Get-MtFamilyParentId -LiteralPrefix $InventoryRow.LiteralPrefix }
    $name = if ($InventoryRow.Name) { [string]$InventoryRow.Name } else { [string]$id }
    $start = $name.IndexOf('See https')
    if ($start -gt 0) { $name = $name.Substring(0, $start).Trim() }
    $title = if ($name.IndexOf(':') -gt 0) { $name.Substring($name.IndexOf(':') + 1).Trim() } else { $name }
    $message = 'This is a Pester-format test and Pester 5.7.1 or later is not installed. Install it with: Install-Module Pester -MinimumVersion 5.7.1 -Scope CurrentUser'
    [pscustomobject][ordered]@{
        Index           = 0
        Id              = $id
        Title           = $title
        Name            = $name
        HelpUrl         = ''
        Severity        = ''
        Tag             = @($InventoryRow.Tags)
        Result          = 'Error'
        ScriptBlock     = ''
        ScriptBlockFile = $InventoryRow.File
        ErrorRecord     = @()
        Block           = $InventoryRow.Block
        Duration        = '00:00:00.000'
        ResultDetail    = [pscustomobject]@{ TestTitle = $null; TestDescription = $message; TestResult = "Error. $message"; TestSkipped = $null; SkippedReason = $message; TestInvestigate = $false; Severity = $null; Service = $null }
        Source          = if ($Origin) { $Origin.Source } else { $null }
        Suite           = if ($Origin) { $Origin.Suite } else { $null }
        Format          = 'Pester'
        ReasonCode      = 'PesterNotAvailable'
        ReasonDetail    = $message
        ParentId        = if ($InventoryRow.IsStatic) { $null } else { $id }
        InstanceId      = $null
        Parameters      = @()
        Diagnostics     = @()
    }
}
