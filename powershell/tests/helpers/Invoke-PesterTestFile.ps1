<#
.SYNOPSIS
Runs unit test files with Pester, one Invoke-Pester per file, and returns a summary of each run.

.DESCRIPTION
pester.ps1 runs this script in a new pwsh process for each batch of test files. A test file that imports the
module with -Force leaves the previous copy of the module in memory, because the classes the module defines keep
it alive. In one process that grew to several GB over the whole unit test run. A process per batch returns that
memory when the batch is done, and lets pester.ps1 run several batches at once.

With -SummaryPath the summaries are written there as JSON, which is how pester.ps1 reads them back from the
child process. Without it they are returned (pester.ps1 -InProcess).
#>
param (
    # The test files. pwsh -File cannot pass an array, so one string may also hold several paths separated by |.
    [Parameter(Mandatory)]
    [string[]] $Path,

    # The folder for the JUnit XML results, one TEST-<file>.xml per test file.
    [Parameter(Mandatory)]
    [string] $ResultFolder,

    [string] $SummaryPath,

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string] $Verbosity = 'None'
)

$Path = @($Path -split '\|' | Where-Object { $_ })

if (-not (Get-Module Maester)) {
    Import-Module "$PSScriptRoot/../../Maester.psd1"
}
Import-Module PSModuleDevelopment
Import-Module Pester -RequiredVersion 5.7.1

$summaries = foreach ($file in $Path) {
    $config = New-PesterConfiguration
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path $ResultFolder "TEST-$([System.IO.Path]::GetFileNameWithoutExtension($file)).xml"
    $config.TestResult.OutputFormat = 'JUnitXml'
    $config.Run.Path = $file
    $config.Run.PassThru = $true
    $config.Output.Verbosity = $Verbosity
    $result = Invoke-Pester -Configuration $config

    $failures = [System.Collections.Generic.List[object]]::new()
    $scriptAnalyzerFailures = [System.Collections.Generic.List[string]]::new()
    foreach ($container in $result.Containers) {
        if ($container.Result -eq 'Failed' -and $container.ErrorRecord) {
            $failures.Add([pscustomobject]@{
                Block   = Split-Path -Leaf $file
                Name    = 'Discovery or BeforeAll/AfterAll'
                Result  = 'Failed'
                Message = ($container.ErrorRecord | ForEach-Object { $_.DisplayErrorMessage }) -join [Environment]::NewLine
            })
        }
    }
    foreach ($test in $result.Tests) {
        if ($test.Result -notin 'Passed', 'Skipped') {
            $failures.Add([pscustomobject]@{
                Block   = $test.Block.ExpandedName
                Name    = "It $($test.ExpandedName)"
                Result  = $test.Result
                Message = $test.ErrorRecord.DisplayErrorMessage
            })
        }
        if ($test.Result -eq 'Failed' -and $test.Tag -contains 'ScriptAnalyzerRule' -and $test.StandardOutput) {
            # Formatted as text here: the analyzer's records do not survive the trip through JSON. The width is set
            # because a child process with redirected output can report a console width of 0.
            $text = $test.StandardOutput | Select-Object RuleName, Severity, ScriptName, Line, Message | Format-List | Out-String -Width 4096
            $scriptAnalyzerFailures.Add($text.Trim())
        }
    }

    [pscustomobject]@{
        Path                   = $file
        TotalCount             = $result.TotalCount
        FailedCount            = $result.FailedCount + $result.FailedContainersCount
        Duration               = $result.Duration.TotalSeconds
        Failures               = $failures.ToArray()
        ScriptAnalyzerFailures = $scriptAnalyzerFailures.ToArray()
    }
}

if ($SummaryPath) {
    ConvertTo-Json -InputObject @($summaries) -Depth 5 | Set-Content -LiteralPath $SummaryPath -Encoding utf8
} else {
    $summaries
}
