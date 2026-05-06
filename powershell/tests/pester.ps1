param (
    $TestGeneral = $true,

    $TestFunctions = $true,

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [Alias('Show')]
    $Output = "None",

    $Include = "*",

    $Exclude = "",

    [switch]
    $NoError,

    # When set (or when $env:PESTER_COVERAGE equals 'true'), runs all tests in a single
    # combined Pester invocation and generates a JaCoCo code-coverage report.
    [switch]
    $Coverage
)

Write-Host "Starting Tests"
Write-Host "Importing Module"

Remove-Module Maester -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\Maester.psd1"

Import-Module PSModuleDevelopment
Import-Module Pester

Write-PSFMessage -Level Important -Message "Creating test result folder"
$null = New-Item -Path "$PSScriptRoot\..\.." -Name TestResults -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0

$testresults = [System.Collections.Generic.List[object]]::new()
$scriptAnalyzerFailures = [System.Collections.Generic.List[object]]::new()
$config = New-PesterConfiguration
$config.TestResult.Enabled = $true

# Detect coverage mode: -Coverage switch or PESTER_COVERAGE=true environment variable.
$enableCoverage = $Coverage.IsPresent -or ($env:PESTER_COVERAGE -eq 'true')
if ($enableCoverage) {
    $coverageOutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" "CodeCoverage.xml"
    $config.CodeCoverage.Enabled      = $true
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath   = $coverageOutputPath
    # Scope coverage to module source directories only (exclude tests/).
    $config.CodeCoverage.Path         = @(
        (Resolve-Path "$PSScriptRoot\..\public").Path,
        (Resolve-Path "$PSScriptRoot\..\internal").Path
    )
    $config.CodeCoverage.RecursePaths = $true
    Write-PSFMessage -Level Important -Message "Code coverage enabled. Output: $coverageOutputPath"
}

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

if ($enableCoverage) {
    #region Combined single-run mode (required for coherent coverage data)
    # When coverage is enabled, all test files are gathered and passed to a single
    # Invoke-Pester call so Pester can produce one consolidated JaCoCo report.
    $allTestPaths = [System.Collections.Generic.List[string]]::new()

    if ($TestGeneral) {
        foreach ($file in (Get-ChildItem "$PSScriptRoot\general" -Filter '*.Tests.ps1' -File)) {
            if ($file.Name -notlike $Include) { continue }
            if ($file.Name -like $Exclude) { continue }
            $allTestPaths.Add($file.FullName)
        }
    }

    if ($TestFunctions) {
        foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File -Filter '*.Tests.ps1')) {
            if ($file.Name -notlike $Include) { continue }
            if ($file.Name -like $Exclude) { continue }
            $allTestPaths.Add($file.FullName)
        }
    }

    if ($allTestPaths.Count -eq 0) {
        Write-PSFMessage -Level Warning -Message "No test files matched the current filters in coverage mode; skipping Invoke-Pester."
    } else {
    Write-PSFMessage -Level Important -Message "Running $($allTestPaths.Count) test files in combined coverage run"
    $config.TestResult.OutputPath   = Join-Path "$PSScriptRoot\..\..\TestResults" "TEST-Coverage.xml"
    $config.TestResult.OutputFormat = "NUnitXml"
    $config.Run.Path                = $allTestPaths.ToArray()
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
    } # end if ($allTestPaths.Count -gt 0)
    #endregion Combined single-run mode
} else {
    #region Run General Tests
    if ($TestGeneral)
    {
        Write-PSFMessage -Level Important -Message "Modules imported, proceeding with general tests"
        foreach ($file in (Get-ChildItem "$PSScriptRoot\general" -Filter '*.Tests.ps1' -File))
        {
            if ($file.Name -notlike $Include) { continue }
            if ($file.Name -like $Exclude) { continue }

            Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
            $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" "TEST-$($file.BaseName).xml"
            $config.TestResult.OutputFormat = "JUnitXml"
            $config.Run.Path = $file.FullName
            $config.Run.PassThru = $true
            $config.Output.Verbosity = $Output
            $result = Invoke-Pester -Configuration $config

            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount + $result.FailedContainersCount
            foreach ($test in $result.Tests) {
                if ($test.Result -ne 'Passed') {
                    $failedTest = [pscustomobject]@{
                        Block   = $test.Block.ExpandedName
                        Name    = "It $($test.ExpandedName)"
                        Result  = $test.Result
                        Message = $test.ErrorRecord.DisplayErrorMessage
                    }
                    $null = $testresults.Add($failedTest)
                }

                if ($test.Result -eq 'Failed' -and $test.Tag -contains 'ScriptAnalyzerRule' -and $test.StandardOutput) {
                    $null = $scriptAnalyzerFailures.Add($test.StandardOutput)
                }
            }
        }
    }
    #endregion Run General Tests

    #region Test Commands
    if ($TestFunctions)
    {
        Write-PSFMessage -Level Important -Message "Proceeding with individual tests"
        foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File -Filter '*.Tests.ps1'))
        {
            if ($file.Name -notlike $Include) { continue }
            if ($file.Name -like $Exclude) { continue }

            Write-PSFMessage -Level Significant -Message "  Executing $($file.Name)"
            $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" "TEST-$($file.BaseName).xml"
            $config.Run.Path = $file.FullName
            $config.Run.PassThru = $true
            $config.Output.Verbosity = $Output
            $result = Invoke-Pester -Configuration $config

            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount + $result.FailedContainersCount
            foreach ($test in $result.Tests) {
                if ($test.Result -notin 'Passed','Skipped') {
                    $failedTest = [pscustomobject]@{
                        Block   = $test.Block.ExpandedName
                        Name    = "It $($test.ExpandedName)"
                        Result  = $test.Result
                        Message = $test.ErrorRecord.DisplayErrorMessage
                    }
                    $null = $testresults.Add($failedTest)
                }
            }
        }
    }
    #endregion Test Commands
}

# Print any ScriptAnalyzer output (runs for both coverage and normal modes)
$scriptAnalyzerFailures | Out-Host

# If BOM rule appears, show a clear fix script
$hasBomRuleFailure = Test-ContainsFailureRule -RuleName 'PSUseBOMForUnicodeEncodedFile' -ScriptAnalyzerFailures $scriptAnalyzerFailures -TestResults $testresults

if ($hasBomRuleFailure) {
    Write-Host "`n❌ To fix PSUseBOMForUnicodeEncodedFile → Run the following script with the affected file to fix the issue`n" -ForegroundColor Yellow
    @'
$affectedFilePath = '/Users/merill/GitHub/maester/powershell/public/maester/entra/Test-MtTenantCreationRestricted.ps1'
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
