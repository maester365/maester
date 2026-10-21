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

    # How many test files run at the same time, each in its own pwsh process. The default is half the
    # processor count, at most 4. Each process needs about 0.5 to 1 GB of memory, so lower this on a small VM.
    [ValidateRange(1, 64)]
    [int]
    $ThrottleLimit = [Math]::Max(1, [Math]::Min(4, [int][Math]::Floor([Environment]::ProcessorCount / 2))),

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
    $runnerArguments = @{ Verbosity = $Output }

    if ($InProcess) {
        Write-PSFMessage -Level Important -Message "Running $($testFiles.Count) test files in this process"
        $runs = foreach ($file in $testFiles) {
            Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
            [pscustomobject]@{
                File    = $file
                Summary = & $runner -Path $file.FullName -ResultPath (Join-Path $resultRoot "TEST-$($file.BaseName).xml") @runnerArguments
                Output  = @()
            }
        }
    } else {
        Write-PSFMessage -Level Important -Message "Running $($testFiles.Count) test files, $ThrottleLimit at a time, each in its own pwsh process"
        $pwsh = (Get-Process -Id $PID).Path
        $runs = $testFiles | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            $file = $_
            $summaryPath = Join-Path ([System.IO.Path]::GetTempPath()) "maester-unit-$([guid]::NewGuid().ToString('n')).json"
            $resultPath = Join-Path $using:resultRoot "TEST-$($file.BaseName).xml"
            $runnerArguments = $using:runnerArguments
            $output = @(& $using:pwsh -NoProfile -NonInteractive -File $using:runner -Path $file.FullName -ResultPath $resultPath -SummaryPath $summaryPath @runnerArguments 2>&1 | ForEach-Object { "$_" })
            $summary = $null
            if (Test-Path -LiteralPath $summaryPath) {
                $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
                Remove-Item -LiteralPath $summaryPath -Force
            }
            [pscustomobject]@{ File = $file; Summary = $summary; Output = $output }
        } | ForEach-Object {
            # Reported as each file finishes, so the console shows progress while the others run.
            $run = $_
            $state = if (-not $run.Summary) { 'crashed' } elseif ($run.Summary.FailedCount) { "$($run.Summary.FailedCount) failed" } else { 'passed' }
            $seconds = if ($run.Summary) { '{0:n1}s' -f $run.Summary.Duration } else { '' }
            Write-PSFMessage -Level Significant -Message "  Executed <c='em'>$($run.File.Name)</c> $seconds $state"
            if ($run.Output -and ($Output -ne 'None' -or -not $run.Summary)) {
                $run.Output | Out-Host
            }
            $run
        }
    }

    foreach ($run in $runs) {
        if (-not $run.Summary) {
            # The process ended without writing its summary, so the file did not finish.
            $totalFailed++
            $null = $testresults.Add([pscustomobject]@{
                Block   = $run.File.Name
                Name    = 'Test file run'
                Result  = 'Failed'
                Message = "The pwsh process running this file ended before Pester finished. Its output:`n$(($run.Output | Select-Object -Last 40) -join "`n")"
            })
            continue
        }
        $totalRun += $run.Summary.TotalCount
        $totalFailed += $run.Summary.FailedCount
        foreach ($failure in $run.Summary.Failures) { $null = $testresults.Add($failure) }
        foreach ($text in $run.Summary.ScriptAnalyzerFailures) { $null = $scriptAnalyzerFailures.Add($text) }
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
