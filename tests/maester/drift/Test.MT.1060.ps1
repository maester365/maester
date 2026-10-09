function Get-MtDriftFolderInstance {
    <#
    .SYNOPSIS
    Returns four MT.1060 instances per drift folder.

    .DESCRIPTION
    Instance source of the MT.1060 family. Lists the subfolders of the drift root (the
    MAESTER_FOLDER_DRIFT environment variable, set by Invoke-Maester -DriftRoot) and returns one instance
    per folder and check: <folder>.1 to <folder>.4, with the folder name made safe for a test ID. Without
    a drift root there are no instances. The 2.x tags MT1060.<n>, MT1060.<folder> and MT1060.<folder>.<n>
    are kept on each instance.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $driftRoot = $env:MAESTER_FOLDER_DRIFT
    if ([string]::IsNullOrEmpty($driftRoot) -or -not (Test-Path -LiteralPath $driftRoot -PathType Container)) { return }

    $titles = @{
        1 = "Drift baseline in '{0}' is valid JSON"
        2 = "Drift current in '{0}' is valid JSON"
        3 = "Drift current in '{0}' has no missing properties"
        4 = "Drift all values in '{0}' match"
    }
    foreach ($folder in @(Get-ChildItem -LiteralPath $driftRoot -Directory | Sort-Object -Property Name)) {
        # Instance grammar: ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$, and the check number takes two characters.
        $safeName = ($folder.Name -replace '[^A-Za-z0-9._-]', '_') -replace '^[^A-Za-z0-9]+', ''
        if (-not $safeName) { $safeName = 'folder' }
        if ($safeName.Length -gt 120) { $safeName = $safeName.Substring(0, 120) }
        foreach ($check in 1..4) {
            [pscustomobject]@{
                Id    = "$safeName.$check"
                Title = $titles[$check] -f $folder.Name
                Tag   = @("MT1060.$check", "MT1060.$($folder.Name)", "MT1060.$($folder.Name).$check")
                Data  = [pscustomobject]@{ Name = $folder.Name; Path = $folder.FullName; Check = $check }
            }
        }
    }
}

function Get-MtDriftFolderState {
    <#
    .SYNOPSIS
    Reads the baseline, current and settings files of a drift folder and compares them.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Full path of the drift folder.
        [Parameter(Mandatory)] [string] $Path
    )

    $state = [pscustomobject]@{
        HasBaseline  = $false
        BaselineData = $null
        BaselineError = $null
        HasCurrent   = $false
        CurrentData  = $null
        CurrentError = $null
        Issues       = @()
    }

    $baselinePath = Join-Path -Path $Path -ChildPath 'baseline.json'
    $state.HasBaseline = Test-Path -LiteralPath $baselinePath -PathType Leaf
    if ($state.HasBaseline) {
        try {
            $state.BaselineData = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json -Depth 100
        } catch {
            $state.BaselineError = $_.Exception.Message
        }
    }

    $currentPath = Join-Path -Path $Path -ChildPath 'current.json'
    $state.HasCurrent = Test-Path -LiteralPath $currentPath -PathType Leaf
    if ($state.HasCurrent) {
        try {
            $state.CurrentData = Get-Content -LiteralPath $currentPath -Raw | ConvertFrom-Json -Depth 100
        } catch {
            $state.CurrentError = $_.Exception.Message
        }
    }

    # settings.json is optional; currently only ExcludeProperties is supported.
    $settings = $null
    $settingsPath = Join-Path -Path $Path -ChildPath 'settings.json'
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        try {
            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Could not parse settings.json in $(Split-Path -Path $Path -Leaf): $($_.Exception.Message)"
        }
    }

    if ($null -ne $state.BaselineData -and $null -ne $state.CurrentData) {
        try {
            $state.Issues = @(Compare-MtJsonObject -Baseline $state.BaselineData -Current $state.CurrentData -Settings $settings)
        } catch {
            # If an error occurs during comparison, capture it as an issue
            $state.Issues = @([MtPropertyDifference]::new('', 'N/A', 'N/A', "An error occurred while comparing JSON objects: $($_.Exception.Message)", 'ComparisonError'))
        }
    }
    $state
}

function Test-MtDriftFolder {
    <#
    .SYNOPSIS
    Checks one drift folder: valid baseline, valid current file, no missing properties, no drifted values.

    .DESCRIPTION
    Runs four times per drift folder (see Get-MtDriftFolderInstance). Check 1 and 2 pass when baseline.json
    and current.json exist and hold JSON data. Check 3 passes when current.json has every property of
    baseline.json, and check 4 when every value matches; both are skipped when either file is missing or
    is not valid JSON.

    .LINK
    https://maester.dev/docs/tests/MT.1060
    #>
    [MaesterTest(
        Id = 'MT.1060',
        Title = 'Drift folders should match their baseline.',
        Severity = 'Medium',
        Category = 'Maester/Drift',
        Tag = ('Maester', 'MT1060'),
        Service = 'None',
        InstanceSource = 'Get-MtDriftFolderInstance',
        Author = 'svrooij'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The drift folder and check to run, supplied by the engine.
        $Instance
    )

    $folder = $Instance.Data
    $state = Get-MtDriftFolderState -Path $folder.Path

    switch ($folder.Check) {
        1 {
            $description = 'The `baseline.json` file should be valid JSON.'
            if (-not $state.HasBaseline) {
                Add-MtTestResultDetail -Description $description -Result "The baseline file ``baseline.json`` was not found in ``$($folder.Path)``."
                return $false
            }
            if ($null -eq $state.BaselineData) {
                Add-MtTestResultDetail -Description $description -Result "The baseline file in ``$($folder.Path)`` does not contain valid JSON data. $($state.BaselineError)"
                return $false
            }
            Add-MtTestResultDetail -Description $description -Result 'The baseline file is valid JSON.'
            return $true
        }
        2 {
            $description = 'The `current.json` file should be valid JSON, how else can we compare it?'
            if (-not $state.HasCurrent) {
                Add-MtTestResultDetail -Description $description -Result "The current file ``current.json`` was not found in ``$($folder.Path)``."
                return $false
            }
            if ($null -eq $state.CurrentData) {
                Add-MtTestResultDetail -Description $description -Result "The current file in ``$($folder.Path)`` does not contain valid JSON data. $($state.CurrentError)"
                return $false
            }
            Add-MtTestResultDetail -Description $description -Result 'The current file is valid JSON.'
            return $true
        }
        3 {
            $description = 'The `current.json` file should not have any missing properties compared to the `baseline.json` file.'
            if ($null -eq $state.BaselineData -or $null -eq $state.CurrentData) {
                Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'The baseline or current file is missing or is not valid JSON.'
                return $null
            }
            $missingProperties = @($state.Issues | Where-Object { $_.Reason -eq 'MissingProperty' } | Select-Object -ExpandProperty PropertyName -Unique)
            if ($missingProperties.Count -gt 0) {
                $formattedMissing = "The following properties are in the baseline but missing in ``current.json``: `n`n"
                $missingProperties | ForEach-Object { $formattedMissing += "- ``$_```n" }
                $formattedMissing += "`n"
                $formattedMissing += "Files compared in folder: ``$($folder.Path)```n"
                Add-MtTestResultDetail -Result $formattedMissing -Description $description
                return $false
            }
            Add-MtTestResultDetail -Result 'No missing properties found in current.json.' -Description $description
            return $true
        }
        4 {
            $description = 'The `current.json` file should not drift from the `baseline.json` file.'
            if ($null -eq $state.BaselineData -or $null -eq $state.CurrentData) {
                Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'The baseline or current file is missing or is not valid JSON.'
                return $null
            }
            $propertyIssues = @($state.Issues | Where-Object { $_.Reason -ne 'MissingProperty' })
            if ($propertyIssues.Count -gt 0) {
                $formattedIssues = '| Property | Reason | Expected Value | Actual Value | Description |' + "`n"
                $formattedIssues += '|----------|---------|----------------|--------------|-------------|' + "`n"
                $propertyIssues | ForEach-Object {
                    $formattedIssues += "| ``$($_.PropertyName)`` | $($_.Reason) | ``$($_.ExpectedValue)`` | ``$($_.ActualValue)`` | $($_.Description) |`n"
                }
                $formattedIssues += "`n"
                $formattedIssues += "Files compared in folder: ``$($folder.Path)```n"
                Add-MtTestResultDetail -Result $formattedIssues -Description $description
                return $false
            }
            Add-MtTestResultDetail -Result 'No issues found in current.json.' -Description $description
            return $true
        }
    }
}
