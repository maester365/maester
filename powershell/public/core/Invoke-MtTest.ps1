function Invoke-MtTest {
    <#
    .SYNOPSIS
    Runs one or more Maester native tests through the engine and returns their result rows.

    .DESCRIPTION
    Runs built-in tests by ID, or the native tests (Test.<ID>.ps1) in a file or folder, with the same
    applicability gates, parameter binding and result rows as Invoke-Maester, but without reports.

    This is how a custom test reuses a built-in check (instead of calling its function directly), and
    how a test author runs the test they are writing.

    .PARAMETER Id
    Test IDs to run: exact IDs or '*' wildcards. A family's instance ID runs that instance.

    .PARAMETER Path
    A Test.<ID>.ps1 file or a folder of them. Without -Id every native test in it runs.

    .PARAMETER Parameter
    Parameter values for the test. Allowed only when exactly one test is selected.

    .PARAMETER Config
    The run configuration: a path, an object or an array of them, as for Invoke-Maester. Defaults to the
    configuration of the current Invoke-Maester run, else the config files found from -Path or the current folder.

    .EXAMPLE
    Invoke-MtTest -Id MT.1005

    Runs the built-in test MT.1005 and returns its result row.

    .EXAMPLE
    Invoke-MtTest -Path ./Custom/Test.CONTOSO.1001.ps1 -Parameter @{ MaximumDays = 30 }

    Runs a custom test with a parameter value, as while writing it.

    .LINK
    https://maester.dev/docs/commands/Invoke-MtTest
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Id,

        [Parameter()]
        [string] $Path,

        [Parameter()]
        [hashtable] $Parameter,

        [Parameter()]
        [object] $Config
    )

    if (-not $Id -and -not $Path) {
        Write-Error 'Specify the tests to run with -Id, -Path or both.'
        return
    }

    $tests = [System.Collections.Generic.List[object]]::new()
    if ($Path) {
        if (-not (Test-Path -LiteralPath $Path)) { Write-Error "The path '$Path' does not exist."; return }
        $root = if (Test-Path -LiteralPath $Path -PathType Container) { (Resolve-Path -LiteralPath $Path).Path } else { Split-Path (Resolve-Path -LiteralPath $Path).Path -Parent }
        foreach ($t in @(Get-MtNativeTestInventory -Path $Path -Root $root)) { $tests.Add($t) }
    }
    if ($Id) {
        $pool = if ($Path) { @($tests) } else { @(Get-MtTestCatalog) }
        $selected = @($pool | Where-Object {
                $t = $_
                (Test-MtIdMatch -Id $t.Id -Pattern $Id) -or ($t.InstanceSource -and ($Id | Where-Object { $_ -like "$($t.Id).*" }))
            })
        $unknown = @($Id | Where-Object { $i = $_; -not ($selected | Where-Object { (Test-MtIdMatch -Id $_.Id -Pattern @($i)) -or ($_.InstanceSource -and $i -like "$($_.Id).*") }) })
        if ($unknown.Count -gt 0) {
            Write-Error "No native test matches: $($unknown -join ', '). Use Get-MtTest to list the tests."
            if ($selected.Count -eq 0) { return }
        }
        $tests = [System.Collections.Generic.List[object]]::new()
        foreach ($t in $selected) { $tests.Add($t) }
    }
    if ($tests.Count -eq 0) { Write-Error 'No native tests to run.'; return }
    if ($Parameter -and $tests.Count -ne 1) { Write-Error "-Parameter can be used only when exactly one test is selected; $($tests.Count) are."; return }

    # Inside an Invoke-Maester run the run's config is kept; otherwise it is resolved for this call.
    $savedConfig = $__MtSession.MaesterConfig
    $ownsConfig = $null -eq $savedConfig -or $null -ne $Config
    try {
        if ($ownsConfig) {
            $searchPath = if ($Path) { $(if (Test-Path -LiteralPath $Path -PathType Container) { $Path } else { Split-Path $Path -Parent }) } else { (Get-Location).Path }
            $__MtSession.MaesterConfig = Resolve-MtRunConfig -Path $searchPath -Config $Config -WarningAction SilentlyContinue
        }
        $runConfig = $__MtSession.MaesterConfig
        $selection = Resolve-MtSelection -RunConfig $runConfig -TestId @($tests | ForEach-Object { $_.Id })
        $selection.DefaultAction = 'Run'
        # Instance IDs given with -Id select those instances only.
        if ($Id) { $selection.TestId = @(@($tests | ForEach-Object { $_.Id }) | Where-Object { $tid = $_; $Id | Where-Object { $tid -like $_ } }) + @($Id | Where-Object { $i = $_; $tests | Where-Object { $_.InstanceSource -and $i -like "$($_.Id).*" } }) }
        $services = @($tests | ForEach-Object { $_.Service } | Where-Object { $_ } | Select-Object -Unique)
        $context = Get-MtTenantContext -Service $(if ($services) { $services } else { @('Graph') }) -Environment $(if ($runConfig.PSObject.Properties['Environment']) { $runConfig.Environment } else { $null })
        $override = @{}
        if ($Parameter) { $override[$tests[0].Id] = $Parameter }
        $plan = @(Resolve-MtNativePlan -Test @($tests) -Selection $selection -RunConfig $runConfig -TenantContext $context -ParameterOverride $override)
        Invoke-MtNativePlan -Plan $plan -RunConfig $runConfig -Selection $selection
    } finally {
        if ($ownsConfig) { $__MtSession.MaesterConfig = $savedConfig }
    }
}
