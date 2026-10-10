<#
.SYNOPSIS
    Benchmarks Maester 2.x (PowerShell Gallery, Pester runner) against Maester 3.x (this checkout, native engine).

.DESCRIPTION
    Every measurement runs in a fresh pwsh process. The script:

    - saves the 2.x module from the PowerShell Gallery (with its dependencies) to a work folder, so the
      3.x checkout is never shadowed by an installed Maester, and installs the 2.x tests there
    - runs each scenario once cold (a new PowerShell module analysis cache) and -Repetitions times warm,
      alternating between the two versions so background noise is spread evenly
    - records wall time of the measured step, the whole process, and memory (peak from /usr/bin/time on
      macOS and Linux, from the Process object on Windows; working set and GC heap at the end)
    - writes all samples, summary statistics and the environment to a JSON file

    No tenant is connected: every test that needs a connection skips, which isolates engine and report
    overhead from Graph latency. Telemetry and update checks are turned off.

    Scenarios:
      Import      Import-Module (2.x: Pester + Maester + dependencies; 3.x: Maester + dependencies)
      Discovery   2.x: Invoke-Pester with Run.SkipRun on the installed tests; 3.x: Get-MtTest
      DryRun      2.x: Invoke-Maester with a PesterConfiguration that sets Run.SkipRun; 3.x: Invoke-Maester -DryRun
      Run         Invoke-Maester -NonInteractive with every output (HTML, JSON, Markdown) to a temp folder
      RunSubset   Run with -Tag <SubsetTag> (default CA)
      Report      Run with -PassThru, then times HTML, JSON and Markdown generation from the results in-process

    Isolation: with -ModulePath Isolated (default) PSModulePath holds only the benchmark's dependencies.
    On macOS and Linux the user module folder is hidden by pointing XDG_DATA_HOME at an empty folder.
    On Windows PowerShell always adds Documents\PowerShell\Modules, so modules installed there can still
    be auto-loaded by tests (for example ExchangeOnlineManagement); use -ModulePath Inherit on every
    platform to measure with the modules the current user has installed.

.PARAMETER Maester3Path
    Maester.psd1 of the 3.x version. Defaults to ./module/Maester.psd1 (run ./build/Build-MaesterModule.ps1
    first), then ./powershell/Maester.psd1 (source).

.PARAMETER Maester2Version
    The 2.x version to download from the PowerShell Gallery.

.PARAMETER PesterVersion
    Pester version(s) used for 2.x. Each is benchmarked as its own 2.x variant. Defaults to the version
    Save-Module downloads (the newest), which is what a new Install-Module Maester gets.

.PARAMETER Scenario
    Scenarios to run.

.PARAMETER Repetitions
    Warm repetitions per scenario and version (the cold run is extra).

.PARAMETER WorkPath
    Folder for downloaded modules, installed 2.x tests, per-run output and caches. Reused between runs.

.PARAMETER OutputPath
    The results JSON file. Defaults to <WorkPath>/results-<timestamp>.json.

.EXAMPLE
    ./build/Build-MaesterModule.ps1
    ./build/perf/Measure-MaesterPerformance.ps1 -Repetitions 5

.EXAMPLE
    ./build/perf/Measure-MaesterPerformance.ps1 -Scenario Import, Discovery -Repetitions 10 -PesterVersion 5.7.1, 6.2.0
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Progress output for an interactive benchmark')]
[CmdletBinding(DefaultParameterSetName = 'Benchmark')]
param(
    [Parameter(ParameterSetName = 'Benchmark')]
    [string] $Maester3Path,

    [Parameter(ParameterSetName = 'Benchmark')]
    [string] $Maester2Version = '2.3.0',

    [Parameter(ParameterSetName = 'Benchmark')]
    [string[]] $PesterVersion,

    [Parameter(ParameterSetName = 'Benchmark')]
    [ValidateSet('Import', 'Discovery', 'DryRun', 'Run', 'RunSubset', 'Report')]
    [string[]] $Scenario = @('Import', 'Discovery', 'DryRun', 'Run', 'RunSubset', 'Report'),

    [Parameter(ParameterSetName = 'Benchmark')]
    [ValidateRange(1, 100)]
    [int] $Repetitions = 5,

    [Parameter(ParameterSetName = 'Benchmark')]
    [string] $SubsetTag = 'CA',

    [Parameter(ParameterSetName = 'Benchmark')]
    [ValidateSet('Isolated', 'Inherit')]
    [string] $ModulePath = 'Isolated',

    [Parameter(ParameterSetName = 'Benchmark')]
    [string] $WorkPath = (Join-Path ([System.IO.Path]::GetTempPath()) 'maester-perf'),

    [Parameter(ParameterSetName = 'Benchmark')]
    [string] $OutputPath,

    [Parameter(ParameterSetName = 'Benchmark')]
    [ValidateRange(60, 7200)]
    [int] $TimeoutSeconds = 1200,

    # Internal: the spec file of one measurement, used when the script runs itself as a worker.
    [Parameter(ParameterSetName = 'Worker', Mandatory)]
    [string] $WorkerSpec
)

#region Worker: one measurement in this (fresh) process
if ($PSCmdlet.ParameterSetName -eq 'Worker') {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    $spec = Get-Content -LiteralPath $WorkerSpec -Raw | ConvertFrom-Json
    $result = [ordered]@{ Version = $spec.Label; Scenario = $spec.Scenario; Error = $null }

    function Get-MemorySnapshot {
        $p = [System.Diagnostics.Process]::GetCurrentProcess()
        $p.Refresh()
        $mb = { param($v) if ($v -gt 0) { [math]::Round($v / 1MB, 1) } else { $null } }
        [ordered]@{
            WorkingSetMB     = & $mb $p.WorkingSet64
            PrivateMB        = & $mb $p.PrivateMemorySize64   # 0 (null) on macOS
            PeakWorkingSetMB = & $mb $p.PeakWorkingSet64      # 0 (null) on macOS
            GcHeapMB         = [math]::Round([GC]::GetTotalMemory($false) / 1MB, 1)
        }
    }

    function Get-OutputFileSize([string] $Folder) {
        $sizes = [ordered]@{}
        foreach ($f in @(Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue)) {
            $kind = switch -Regex ($f.Name) { '-summary\.md$' { 'MarkdownSummary'; break } '\.md$' { 'Markdown'; break } '\.html$' { 'Html'; break } '\.json$' { 'Json'; break } default { $f.Extension } }
            $sizes[$kind] = $f.Length
        }
        $sizes
    }

    function Get-ResultCount($r) {
        if (-not $r) { return $null }
        [ordered]@{
            Total = $r.TotalCount; Passed = $r.PassedCount; Failed = $r.FailedCount; Skipped = $r.SkippedCount
            Error = $r.ErrorCount; NotRun = $r.NotRunCount; Investigate = $r.InvestigateCount
        }
    }

    $common = @{ NonInteractive = $true; SkipGraphConnect = $true; DisableTelemetry = $true; SkipVersionCheck = $true; OutputFolder = $spec.OutputFolder; PassThru = $true }
    if ($spec.Is2x) { $common.Path = $spec.TestsPath }
    if ($spec.Tag) { $common.Tag = @($spec.Tag) }

    $sw = [System.Diagnostics.Stopwatch]::new()
    try {
        $sw.Start()
        if ($spec.Is2x) {
            Import-Module Pester -RequiredVersion $spec.PesterVersion
            Import-Module Maester -RequiredVersion $spec.MaesterVersion
        } else {
            Import-Module $spec.Maester3Path
        }
        $sw.Stop()
        $result.ImportSeconds = $sw.Elapsed.TotalSeconds
        $result.MemoryAfterImport = Get-MemorySnapshot

        switch ($spec.Scenario) {
            'Discovery' {
                $sw.Restart()
                if ($spec.Is2x) {
                    # Invoke-Maester's default filter: Preview, LongRunning and AD are excluded.
                    $config = New-PesterConfiguration
                    $config.Run.Path = $spec.TestsPath
                    $config.Run.SkipRun = $true
                    $config.Run.PassThru = $true
                    $config.Output.Verbosity = 'None'
                    $config.Filter.ExcludeTag = @('Preview', 'LongRunning', 'AD')
                    $r = Invoke-Pester -Configuration $config
                    $result.StepSeconds = $sw.Elapsed.TotalSeconds
                    $result.Discovered = @($r.Tests | Where-Object ShouldRun).Count
                    $result.DiscoveredAll = @($r.Tests).Count
                } else {
                    $r = @(Get-MtTest)
                    $result.StepSeconds = $sw.Elapsed.TotalSeconds
                    $result.Discovered = $r.Count
                    $result.DiscoveredAll = $r.Count
                }
            }
            'DryRun' {
                $params = $common.Clone()
                if ($spec.Is2x) {
                    $config = New-PesterConfiguration
                    $config.Run.SkipRun = $true
                    $params.PesterConfiguration = $config
                } else {
                    $params.DryRun = $true
                }
                $sw.Restart()
                $r = Invoke-Maester @params 3>$null
                $result.StepSeconds = $sw.Elapsed.TotalSeconds
                $result.Counts = Get-ResultCount $r
            }
            { $_ -in 'Run', 'RunSubset' } {
                $sw.Restart()
                $r = Invoke-Maester @common 3>$null
                $result.StepSeconds = $sw.Elapsed.TotalSeconds
                $result.Counts = Get-ResultCount $r
                $result.OutputBytes = Get-OutputFileSize $spec.OutputFolder
            }
            'Report' {
                $r = Invoke-Maester @common 3>$null
                $result.Counts = Get-ResultCount $r
                $result.OutputBytes = Get-OutputFileSize $spec.OutputFolder
                $module = Get-Module Maester
                $timings = [ordered]@{}
                $sizes = [ordered]@{}
                $sw.Restart(); $json = $r | ConvertTo-Json -Depth 5 -WarningAction SilentlyContinue; $timings.Json = $sw.Elapsed.TotalSeconds
                $sizes.Json = [System.Text.Encoding]::UTF8.GetByteCount($json)
                $sw.Restart(); $html = Get-MtHtmlReport -MaesterResults $r; $timings.Html = $sw.Elapsed.TotalSeconds
                $sizes.Html = [System.Text.Encoding]::UTF8.GetByteCount([string]$html)
                $sw.Restart(); $md = & $module { param($x) Get-MtMarkdownReport -MaesterResults $x } $r; $timings.Markdown = $sw.Elapsed.TotalSeconds
                $sizes.Markdown = [System.Text.Encoding]::UTF8.GetByteCount([string]$md)
                $sw.Restart(); $mds = & $module { param($x) Get-MtMarkdownSummaryReport -MaesterResults $x } $r; $timings.MarkdownSummary = $sw.Elapsed.TotalSeconds
                $sizes.MarkdownSummary = [System.Text.Encoding]::UTF8.GetByteCount([string]$mds)
                $result.ReportSeconds = $timings
                $result.ReportBytes = $sizes
                $result.StepSeconds = ($timings.Values | Measure-Object -Sum).Sum
            }
        }
    } catch {
        $result.Error = "$($_.Exception.Message) at $($_.InvocationInfo.PositionMessage)"
    }
    $result.MemoryEnd = Get-MemorySnapshot
    $result.LoadedModules = @(Get-Module | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Version)" })
    $result.LoadedAssemblies = @([System.AppDomain]::CurrentDomain.GetAssemblies()).Count
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $spec.ResultFile -Encoding utf8
    exit 0
}
#endregion

#region Benchmark driver
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'Run the benchmark on PowerShell 7.4 or later.' }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $Maester3Path) {
    $Maester3Path = @("$repoRoot/module/Maester.psd1", "$repoRoot/powershell/Maester.psd1") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $Maester3Path) { throw 'Maester 3 not found. Run ./build/Build-MaesterModule.ps1 or pass -Maester3Path.' }
}
$Maester3Path = (Resolve-Path $Maester3Path).Path
$m3Manifest = Import-PowerShellDataFile $Maester3Path

$null = New-Item -ItemType Directory -Force -Path $WorkPath
$WorkPath = (Resolve-Path $WorkPath).Path
$depsPath = Join-Path $WorkPath 'deps'          # Graph authentication and Pester, shared by both versions
$m2Path = Join-Path $WorkPath 'maester2'        # Maester 2.x only, added to PSModulePath for 2.x runs
$emptyHome = Join-Path $WorkPath 'xdg-data'     # empty XDG_DATA_HOME: hides the user module folder
$testsPath = Join-Path $WorkPath "tests-$Maester2Version"
$runsPath = Join-Path $WorkPath 'runs'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $OutputPath) { $OutputPath = Join-Path $WorkPath "results-$stamp.json" }
$pwshPath = [System.Environment]::ProcessPath
$systemModules = Join-Path $PSHOME 'Modules'

# Setup: modules side by side in the work folder.
if (-not (Test-Path "$m2Path/Maester/$Maester2Version")) {
    Write-Host "Saving Maester $Maester2Version and its dependencies from the PowerShell Gallery..." -ForegroundColor Cyan
    $download = Join-Path $WorkPath "download-$stamp"
    $null = New-Item -ItemType Directory -Force -Path $download, $m2Path, $depsPath
    Save-Module -Name Maester -RequiredVersion $Maester2Version -Path $download -Repository PSGallery
    Move-Item "$download/Maester" $m2Path -Force
    foreach ($dir in Get-ChildItem $download -Directory) {
        foreach ($ver in Get-ChildItem $dir.FullName -Directory) {
            $target = Join-Path $depsPath "$($dir.Name)/$($ver.Name)"
            if (-not (Test-Path $target)) { $null = New-Item -ItemType Directory -Force (Split-Path $target); Move-Item $ver.FullName $target }
        }
    }
    Remove-Item $download -Recurse -Force
}
foreach ($pv in @($PesterVersion | Where-Object { $_ })) {
    if (-not (Test-Path "$depsPath/Pester/$pv")) {
        Write-Host "Saving Pester $pv..." -ForegroundColor Cyan
        $download = Join-Path $WorkPath "download-pester-$pv"
        $null = New-Item -ItemType Directory -Force -Path $download
        Save-Module -Name Pester -RequiredVersion $pv -Path $download -Repository PSGallery
        $null = New-Item -ItemType Directory -Force "$depsPath/Pester"
        Move-Item "$download/Pester/$pv" "$depsPath/Pester/$pv"
        Remove-Item $download -Recurse -Force
    }
}
if (-not $PesterVersion) {
    $PesterVersion = @(Get-ChildItem "$depsPath/Pester" -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1 -ExpandProperty Name)
}
$m3Required = @($m3Manifest.RequiredModules | Where-Object { $_ -is [hashtable] })
foreach ($req in $m3Required) {
    if (-not (Get-ChildItem "$depsPath/$($req.ModuleName)" -Directory -ErrorAction SilentlyContinue | Where-Object { [version]$_.Name -ge [version]$req.ModuleVersion })) {
        Write-Host "Saving $($req.ModuleName) for Maester 3..." -ForegroundColor Cyan
        Save-Module -Name $req.ModuleName -MinimumVersion $req.ModuleVersion -Path $depsPath -Repository PSGallery
    }
}
$null = New-Item -ItemType Directory -Force -Path $emptyHome, $runsPath

function Get-ChildEnvironment([bool] $Is2x, [string] $CacheHome) {
    $paths = @()
    if ($Is2x) { $paths += $m2Path }
    $paths += $depsPath, $systemModules
    if ($ModulePath -eq 'Inherit') {
        # The current user's modules as well (an installed Maester there is not removed).
        $paths += @($env:PSModulePath -split [System.IO.Path]::PathSeparator | Where-Object { $_ -and $_ -notin $paths })
    }
    $environment = @{
        PSModulePath               = $paths -join [System.IO.Path]::PathSeparator
        POWERSHELL_TELEMETRY_OPTOUT = '1'
        POWERSHELL_UPDATECHECK     = 'Off'
        XDG_CACHE_HOME             = $CacheHome   # PowerShell's module analysis cache: fresh for cold runs
    }
    if ($ModulePath -eq 'Isolated' -and -not $IsWindows) { $environment.XDG_DATA_HOME = $emptyHome }
    $environment
}

function Invoke-MeasuredProcess([hashtable] $Spec, [hashtable] $Environment, [string] $Folder) {
    $specFile = Join-Path $Folder 'spec.json'
    $Spec | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $specFile -Encoding utf8
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = $Folder
    # Peak memory of the whole process comes from the OS: /usr/bin/time on macOS (-l) and Linux (-v).
    $timeTool = if ($IsMacOS -and (Test-Path /usr/bin/time)) { '-l' } elseif ($IsLinux -and (Test-Path /usr/bin/time)) { '-v' }
    if ($timeTool) {
        $psi.FileName = '/usr/bin/time'
        $psi.ArgumentList.Add($timeTool)
        $psi.ArgumentList.Add($pwshPath)
    } else {
        $psi.FileName = $pwshPath
    }
    foreach ($a in '-NoProfile', '-NonInteractive', '-File', $PSCommandPath, '-WorkerSpec', $specFile) { $psi.ArgumentList.Add($a) }
    foreach ($k in $Environment.Keys) { $psi.Environment[$k] = $Environment[$k] }

    $wall = [System.Diagnostics.Stopwatch]::StartNew()
    $p = [System.Diagnostics.Process]::Start($psi)
    $stdout = $p.StandardOutput.ReadToEndAsync()
    $stderr = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutSeconds * 1000)) { $p.Kill($true); throw "Timed out after $TimeoutSeconds s: $($Spec.Label) $($Spec.Scenario)" }
    $p.WaitForExit()
    $wall.Stop()
    $errText = $stderr.Result
    Set-Content -LiteralPath (Join-Path $Folder 'stdout.txt') -Value $stdout.Result
    Set-Content -LiteralPath (Join-Path $Folder 'stderr.txt') -Value $errText

    if (-not (Test-Path $Spec.ResultFile)) { throw "The worker wrote no result ($($Spec.Label) $($Spec.Scenario)); see $Folder/stderr.txt" }
    $r = Get-Content $Spec.ResultFile -Raw | ConvertFrom-Json -AsHashtable
    $r.ProcessSeconds = $wall.Elapsed.TotalSeconds
    if ($IsMacOS) {
        if ($errText -match '(\d+)\s+maximum resident set size') { $r.PeakRssMB = [math]::Round([double]$Matches[1] / 1MB, 1) }
        if ($errText -match '(\d+)\s+peak memory footprint') { $r.PeakFootprintMB = [math]::Round([double]$Matches[1] / 1MB, 1) }
    } elseif ($IsLinux) {
        if ($errText -match 'Maximum resident set size \(kbytes\):\s*(\d+)') { $r.PeakRssMB = [math]::Round([double]$Matches[1] / 1KB, 1) }
    } else {
        $r.PeakRssMB = $r.MemoryEnd.PeakWorkingSetMB
    }
    $r
}

function Get-Stat([double[]] $Values) {
    $v = @($Values | Where-Object { $null -ne $_ } | Sort-Object)
    if ($v.Count -eq 0) { return $null }
    $mid = [math]::Floor($v.Count / 2)
    $median = if ($v.Count % 2) { $v[$mid] } else { ($v[$mid - 1] + $v[$mid]) / 2 }
    $mean = ($v | Measure-Object -Average).Average
    $sd = if ($v.Count -gt 1) { [math]::Sqrt((($v | ForEach-Object { ($_ - $mean) * ($_ - $mean) }) | Measure-Object -Sum).Sum / ($v.Count - 1)) } else { 0 }
    [ordered]@{ Median = [math]::Round($median, 3); Min = [math]::Round($v[0], 3); Max = [math]::Round($v[-1], 3); StdDev = [math]::Round($sd, 3); N = $v.Count }
}

# The variants: 2.x once per Pester version, and 3.x.
$variants = @(foreach ($pv in $PesterVersion) {
        @{ Label = "$Maester2Version (Pester $pv)"; Key = "2x-pester-$pv"; Is2x = $true; PesterVersion = $pv; MaesterVersion = $Maester2Version }
    }) + @(@{ Label = "$($m3Manifest.ModuleVersion) (native)"; Key = '3x'; Is2x = $false })

# Setup: the 2.x tests, installed the way Install-MaesterTests does (without its gallery version check).
if (-not (Test-Path $testsPath)) {
    Write-Host "Installing the Maester $Maester2Version tests to $testsPath..." -ForegroundColor Cyan
    $installEnv = Get-ChildEnvironment -Is2x $true -CacheHome (Join-Path $WorkPath 'cache-setup')
    $saved = @{}; foreach ($k in $installEnv.Keys) { $saved[$k] = [System.Environment]::GetEnvironmentVariable($k); [System.Environment]::SetEnvironmentVariable($k, $installEnv[$k]) }
    try {
        & $pwshPath -NoProfile -NonInteractive -Command "Import-Module Maester -RequiredVersion $Maester2Version; & (Get-Module Maester) { param(`$p) Update-MtMaesterTests -Path `$p -Install } '$testsPath'" *> $null
    } finally {
        foreach ($k in $saved.Keys) { [System.Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    if (-not (Get-ChildItem $testsPath -Recurse -Filter *.Tests.ps1)) { throw "No tests were installed to $testsPath." }
}

# Environment details.
$cpu = if ($IsMacOS) { (sysctl -n machdep.cpu.brand_string) } elseif ($IsLinux) { ((Get-Content /proc/cpuinfo | Select-String '^model name' | Select-Object -First 1) -replace '.*:\s*', '') } else { (Get-CimInstance Win32_Processor | Select-Object -First 1).Name }
$memGB = if ($IsMacOS) { [math]::Round([double](sysctl -n hw.memsize) / 1GB) } elseif ($IsLinux) { [math]::Round(((Get-Content /proc/meminfo -TotalCount 1) -replace '\D', '') / 1MB) } else { [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) }
$gitCommit = try { (git -C (Split-Path $Maester3Path) rev-parse --short HEAD 2>$null) } catch { $null }
$environmentInfo = [ordered]@{
    Date            = (Get-Date).ToString('o')
    OS              = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    Architecture    = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    Cpu             = $cpu
    LogicalCpus     = [System.Environment]::ProcessorCount
    MemoryGB        = $memGB
    PowerShell      = $PSVersionTable.PSVersion.ToString()
    DotNet          = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
    Maester2        = $Maester2Version
    Maester3        = $m3Manifest.ModuleVersion
    Maester3Path    = $Maester3Path
    Maester3Commit  = $gitCommit
    Maester2Tests   = @(Get-ChildItem $testsPath -Recurse -Filter *.Tests.ps1).Count
    PesterVersions  = @($PesterVersion)
    GraphAuth       = @(Get-ChildItem "$depsPath/Microsoft.Graph.Authentication" -Directory | ForEach-Object Name)
    ModulePath      = $ModulePath
    Repetitions     = $Repetitions
    SubsetTag       = $SubsetTag
}
Write-Host ($environmentInfo | ConvertTo-Json) -ForegroundColor DarkGray

$samples = [System.Collections.Generic.List[object]]::new()
foreach ($s in $Scenario) {
    $warmCache = @{}
    # Pass 0 is cold (a new module analysis cache); passes 1..N are warm and reuse the cache of pass 0.
    for ($pass = 0; $pass -le $Repetitions; $pass++) {
        # Alternate the order of the versions between passes.
        $order = @($variants)
        if ($pass % 2) { [array]::Reverse($order) }
        foreach ($v in $order) {
            $folder = Join-Path $runsPath "$stamp/$s/$($v.Key)/$pass"
            $null = New-Item -ItemType Directory -Force -Path $folder, "$folder/out"
            if ($pass -eq 0) { $warmCache[$v.Key] = Join-Path $runsPath "$stamp/cache-$s-$($v.Key)" }
            $spec = @{
                Label = $v.Label; Scenario = $s; Is2x = $v.Is2x; PesterVersion = $v.PesterVersion; MaesterVersion = $v.MaesterVersion
                Maester3Path = $Maester3Path; TestsPath = $testsPath; OutputFolder = "$folder/out"; ResultFile = "$folder/result.json"
                Tag = if ($s -eq 'RunSubset') { $SubsetTag } else { $null }
            }
            $envVars = Get-ChildEnvironment -Is2x $v.Is2x -CacheHome $warmCache[$v.Key]
            Write-Host ("{0,-10} {1,-26} {2}" -f $s, $v.Label, $(if ($pass -eq 0) { 'cold' } else { "warm $pass/$Repetitions" })) -NoNewline
            $r = Invoke-MeasuredProcess -Spec $spec -Environment $envVars -Folder $folder
            $r.Key = $v.Key
            $r.Pass = $pass
            $r.Cold = $pass -eq 0
            $samples.Add($r)
            if ($r.Error) { Write-Host "  ERROR: $($r.Error)" -ForegroundColor Red }
            else { Write-Host ("  step {0:n2}s  import {1:n2}s  process {2:n2}s  peak {3} MB" -f $r.StepSeconds, $r.ImportSeconds, $r.ProcessSeconds, $r.PeakRssMB) -ForegroundColor DarkGray }
        }
    }
}

# Summary: cold sample and warm statistics per scenario and variant.
$summary = foreach ($s in $Scenario) {
    foreach ($v in $variants) {
        $set = @($samples | Where-Object { $_.Scenario -eq $s -and $_.Key -eq $v.Key -and -not $_.Error })
        $warm = @($set | Where-Object { -not $_.Cold })
        $cold = $set | Where-Object Cold | Select-Object -First 1
        $metric = { param($name, $getter) [ordered]@{ Metric = $name; Cold = $(if ($cold) { & $getter $cold }); Warm = Get-Stat @($warm | ForEach-Object { & $getter $_ }) } }
        $last = $set | Select-Object -Last 1
        [ordered]@{
            Scenario = $s
            Version  = $v.Label
            Key      = $v.Key
            Metrics  = @(
                & $metric 'ImportSeconds' { param($x) $x.ImportSeconds }
                if ($s -ne 'Import') { & $metric 'StepSeconds' { param($x) $x.StepSeconds } }
                & $metric 'ProcessSeconds' { param($x) $x.ProcessSeconds }
                & $metric 'PeakRssMB' { param($x) $x.PeakRssMB }
                if ($IsMacOS) { & $metric 'PeakFootprintMB' { param($x) $x.PeakFootprintMB } }
                & $metric 'EndWorkingSetMB' { param($x) $x.MemoryEnd.WorkingSetMB }
                if (-not $IsMacOS) { & $metric 'EndPrivateMB' { param($x) $x.MemoryEnd.PrivateMB } }
                & $metric 'EndGcHeapMB' { param($x) $x.MemoryEnd.GcHeapMB }
                if ($s -eq 'Report') {
                    foreach ($k in 'Html', 'Json', 'Markdown', 'MarkdownSummary') { & $metric "Report${k}Seconds" ([scriptblock]::Create("param(`$x) `$x.ReportSeconds.$k")) }
                }
            )
            Counts        = $last.Counts
            Discovered    = $last.Discovered
            OutputBytes   = $last.OutputBytes
            ReportBytes   = $last.ReportBytes
            LoadedModules = $last.LoadedModules
            Errors        = @($samples | Where-Object { $_.Scenario -eq $s -and $_.Key -eq $v.Key -and $_.Error } | ForEach-Object Error)
        }
    }
}

$output = [ordered]@{ Environment = $environmentInfo; Summary = @($summary); Samples = $samples }
$output | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8

# Console table: warm medians.
$summary | ForEach-Object {
    $row = $_
    foreach ($m in $row.Metrics) {
        [pscustomobject]@{ Scenario = $row.Scenario; Version = $row.Version; Metric = $m.Metric; Cold = $m.Cold; WarmMedian = $m.Warm.Median; WarmMin = $m.Warm.Min; WarmMax = $m.Warm.Max }
    }
} | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
Write-Host "Results: $OutputPath" -ForegroundColor Green
#endregion
