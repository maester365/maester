param (
    $TestGeneral = $true,

    $TestFunctions = $true,

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [Alias('Show')]
    $Output = "None",

    # File name patterns to run, for example 'Get-MtUser*' or 'RepositoryLayout*', 'Help*'.
    [string[]]
    $Include = "*",

    # File name patterns to skip, for example 'Golden*', 'GeneratedFileFormatting*'.
    [string[]]
    $Exclude = "",

    [switch]
    $NoError,

    # When set (or when $env:PESTER_COVERAGE equals 'true'), runs all tests in a single combined Pester invocation and generates a JaCoCo code-coverage report.
    [switch]
    $Coverage,

    # How many pwsh processes run test files at the same time. The default is 2 (1 on a single-core machine):
    # each process needs up to about 1.3 GB of memory, and 4 at once peaked at about 4.4 GB. On a machine with
    # memory to spare, -ThrottleLimit 4 runs the suite in about half the time.
    [ValidateRange(1, 64)]
    [int]
    $ThrottleLimit = [Math]::Min(2, [Environment]::ProcessorCount),

    # How many test files each pwsh process runs before it exits and frees its memory.
    [ValidateRange(1, 1000)]
    [int]
    $FilesPerProcess = 8,

    # Runs every test file in this process, as pester.ps1 used to. Useful when debugging a test,
    # but each file that re-imports the module keeps another copy of it in memory (about 60 MB each).
    [switch]
    $InProcess
)

Write-Host "Starting Tests"
Write-Host "Importing Module"

Remove-Module Maester -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\Maester.psd1"

Import-Module PSModuleDevelopment
Import-Module Pester -RequiredVersion 5.7.1

Write-PSFMessage -Level Important -Message "Creating test result folder"
$resultRoot = (New-Item -Path "$PSScriptRoot\..\.." -Name TestResults -ItemType Directory -Force).FullName

$totalFailed = 0
$totalRun = 0

$testresults = [System.Collections.Generic.List[object]]::new()
$scriptAnalyzerFailures = [System.Collections.Generic.List[object]]::new()

# Detect coverage mode: -Coverage switch or PESTER_COVERAGE=true environment variable.
$enableCoverage = $Coverage.IsPresent -or ($env:PESTER_COVERAGE -eq 'true')

function Test-ContainsFailureRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RuleName,

        [Parameter()]
        $ScriptAnalyzerFailures,

        [Parameter()]
        $TestResults
    )

    # Match in ScriptAnalyzer raw output lines
    if ($ScriptAnalyzerFailures) {
        if ($ScriptAnalyzerFailures | Where-Object { $_ -match [regex]::Escape($RuleName) } | Select-Object -First 1) {
            return $true
        }
    }

    # Match in Pester test failure messages
    if ($TestResults) {
        if ($TestResults | Where-Object { $_.Message -match [regex]::Escape($RuleName) } | Select-Object -First 1) {
            return $true
        }
    }

    return $false
}

function Test-FileSelected {
    param([System.IO.FileInfo] $File)
    if (-not ($Include | Where-Object { $File.Name -like $_ })) { return $false }
    if ($Exclude | Where-Object { $_ -and $File.Name -like $_ }) { return $false }
    return $true
}

$testFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
if ($TestGeneral) {
    foreach ($file in (Get-ChildItem "$PSScriptRoot\general" -Filter '*.Tests.ps1' -File)) {
        if (Test-FileSelected $file) { $testFiles.Add($file) }
    }
}
if ($TestFunctions) {
    foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File -Filter '*.Tests.ps1')) {
        if (Test-FileSelected $file) { $testFiles.Add($file) }
    }
}

if ($testFiles.Count -eq 0) {
    Write-PSFMessage -Level Warning -Message "No test files matched the current filters; skipping Invoke-Pester."
} elseif ($enableCoverage) {
    #region Combined single-run mode (required for coherent coverage data)
    # When coverage is enabled, all test files are passed to a single Invoke-Pester call so Pester can
    # produce one consolidated JaCoCo report.
    $config = New-PesterConfiguration
    $config.TestResult.Enabled = $true
    $coverageOutputPath = Join-Path $resultRoot "CodeCoverage.xml"
    $config.CodeCoverage.Enabled      = $true
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath   = $coverageOutputPath
    # Scope coverage to module source directories only (exclude tests/).
    $config.CodeCoverage.Path         = @(
        (Resolve-Path "$PSScriptRoot\..\public").Path,
        (Resolve-Path "$PSScriptRoot\..\internal").Path
    )
    $config.CodeCoverage.RecursePaths = $true
    # Profiler-based coverage. With breakpoints on every line of the module the coverage run took ten
    # times as long as the other runs, as the tests run the engine end to end many times.
    $config.CodeCoverage.UseBreakpoints = $false
    Write-PSFMessage -Level Important -Message "Code coverage enabled. Output: $coverageOutputPath"

    Write-PSFMessage -Level Important -Message "Running $($testFiles.Count) test files in combined coverage run"
    $config.TestResult.OutputPath   = Join-Path $resultRoot "TEST-Coverage.xml"
    $config.TestResult.OutputFormat = "JUnitXml"
    $config.Run.Path                = [string[]]$testFiles.FullName
    $config.Run.PassThru            = $true
    $config.Output.Verbosity        = $Output
    $result = Invoke-Pester -Configuration $config

    $totalRun    += $result.TotalCount
    $totalFailed += $result.FailedCount + $result.FailedContainersCount
    foreach ($test in $result.Tests) {
        if ($test.Result -notin 'Passed', 'Skipped') {
            $null = $testresults.Add([pscustomobject]@{
                Block   = $test.Block.ExpandedName
                Name    = "It $($test.ExpandedName)"
                Result  = $test.Result
                Message = $test.ErrorRecord.DisplayErrorMessage
            })
        }
        if ($test.Result -eq 'Failed' -and $test.Tag -contains 'ScriptAnalyzerRule' -and $test.StandardOutput) {
            $null = $scriptAnalyzerFailures.Add($test.StandardOutput)
        }
    }
    #endregion Combined single-run mode
} else {
    #region One Invoke-Pester per test file
    $runner = Join-Path $PSScriptRoot 'helpers/Invoke-PesterTestFile.ps1'
    $runnerArguments = @{ ResultFolder = $resultRoot; Verbosity = $Output }

    if ($InProcess) {
        Write-PSFMessage -Level Important -Message "Running $($testFiles.Count) test files in this process"
        $runs = foreach ($file in $testFiles) {
            Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
            [pscustomobject]@{
                Files     = @($file)
                Summaries = @(& $runner -Path $file.FullName @runnerArguments)
                Output    = @()
            }
        }
    } else {
        # Starting pwsh and importing the module and Pester takes about four seconds, so each process runs a
        # batch of files. A batch of eight re-imports the module at most eight times, which keeps a process
        # under about 1 GB.
        $batches = [System.Collections.Generic.List[object]]::new()
        for ($i = 0; $i -lt $testFiles.Count; $i += $FilesPerProcess) {
            $batches.Add(@($testFiles[$i..([Math]::Min($i + $FilesPerProcess, $testFiles.Count) - 1)]))
        }
        Write-PSFMessage -Level Important -Message "Running $($testFiles.Count) test files in $($batches.Count) pwsh processes, $ThrottleLimit at a time"
        $pwsh = (Get-Process -Id $PID).Path
        $runs = $batches | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            $files = $_
            $summaryPath = Join-Path ([System.IO.Path]::GetTempPath()) "maester-unit-$([guid]::NewGuid().ToString('n')).json"
            $runnerArguments = $using:runnerArguments
            $output = @(& $using:pwsh -NoProfile -NonInteractive -File $using:runner -Path ($files.FullName -join '|') -SummaryPath $summaryPath @runnerArguments 2>&1 | ForEach-Object { "$_" })
            $summaries = @()
            if (Test-Path -LiteralPath $summaryPath) {
                $summaries = @(Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json)
                Remove-Item -LiteralPath $summaryPath -Force
            }
            [pscustomobject]@{ Files = $files; Summaries = $summaries; Output = $output }
        } | ForEach-Object {
            # Reported as each batch finishes, so the console shows progress while the others run.
            $run = $_
            foreach ($summary in $run.Summaries) {
                $state = if ($summary.FailedCount) { "$($summary.FailedCount) failed" } else { 'passed' }
                Write-PSFMessage -Level Significant -Message ("  Executed <c='em'>{0}</c> {1:n1}s {2}" -f (Split-Path -Leaf $summary.Path), $summary.Duration, $state)
            }
            $crashed = $run.Summaries.Count -lt $run.Files.Count
            if ($crashed) {
                Write-PSFMessage -Level Warning -Message "  The pwsh process running $($run.Files.Name -join ', ') ended before Pester finished"
            }
            if ($run.Output -and ($Output -ne 'None' -or $crashed)) {
                $run.Output | Out-Host
            }
            $run
        }
    }

    foreach ($run in $runs) {
        if ($run.Summaries.Count -lt $run.Files.Count) {
            # The process ended without writing its summaries, so the files of its batch did not finish.
            $totalFailed++
            $null = $testresults.Add([pscustomobject]@{
                Block   = $run.Files.Name -join ', '
                Name    = 'Test file run'
                Result  = 'Failed'
                Message = "The pwsh process running these files ended before Pester finished. Its output:`n$(($run.Output | Select-Object -Last 40) -join "`n")"
            })
            continue
        }
        foreach ($summary in $run.Summaries) {
            $totalRun += $summary.TotalCount
            $totalFailed += $summary.FailedCount
            foreach ($failure in $summary.Failures) { $null = $testresults.Add($failure) }
            foreach ($text in $summary.ScriptAnalyzerFailures) { $null = $scriptAnalyzerFailures.Add($text) }
        }
    }
    #endregion One Invoke-Pester per test file
}

# Print any ScriptAnalyzer output (runs for both coverage and normal modes)
$scriptAnalyzerFailures | Out-Host

# If BOM rule appears, show a clear fix script
$hasBomRuleFailure = Test-ContainsFailureRule -RuleName 'PSUseBOMForUnicodeEncodedFile' -ScriptAnalyzerFailures $scriptAnalyzerFailures -TestResults $testresults

if ($hasBomRuleFailure) {
    Write-Host "`n❌ To fix PSUseBOMForUnicodeEncodedFile → Run the following script with the affected file to fix the issue`n" -ForegroundColor Yellow
    @'
$affectedFilePath = '/path/to/maester/powershell/public/run/Invoke-Maester.ps1'
$content = Get-Content $affectedFilePath -Raw; $content | Out-File $affectedFilePath -Encoding UTF8BOM

'@ | Out-Host
}

if ($NoError) {
    return $testresults
}
$testresults | Sort-Object Block, Name, Result, Message | Format-List

if ($totalFailed -eq 0) { Write-PSFMessage -Level Critical -Message "All <c='em'>$totalRun</c> tests executed without a single failure!" }
else { Write-PSFMessage -Level Critical -Message "<c='em'>$totalFailed tests</c> out of <c='sub'>$totalRun</c> tests failed!" }

if ($totalFailed -gt 0)
{
    throw "$totalFailed / $totalRun tests failed!"
}
