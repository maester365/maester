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

# The tests run in a child scope of this script, so they can read its variables. A mock's -ParameterFilter that
# tests an unbound parameter, such as { -not $Result }, reads the script's variable of that name instead: after the
# first file of a batch, $result held that file's Pester run and every later filter on -not $Result failed. So the
# script keeps its state in $__mt names and removes its parameters before the first file runs.
$__mtPath = @($Path -split '\|' | Where-Object { $_ })
$__mtResultFolder = $ResultFolder
$__mtSummaryPath = $SummaryPath
$__mtVerbosity = $Verbosity
Remove-Variable -Name Path, ResultFolder, SummaryPath, Verbosity

if (-not (Get-Module Maester)) {
    Import-Module "$PSScriptRoot/../../Maester.psd1"
}
Import-Module PSModuleDevelopment
Import-Module Pester -RequiredVersion 5.7.1

$__mtSummaries = foreach ($__mtFile in $__mtPath) {
    $__mtConfig = New-PesterConfiguration
    $__mtConfig.TestResult.Enabled = $true
    $__mtConfig.TestResult.OutputPath = Join-Path $__mtResultFolder "TEST-$([System.IO.Path]::GetFileNameWithoutExtension($__mtFile)).xml"
    $__mtConfig.TestResult.OutputFormat = 'JUnitXml'
    $__mtConfig.Run.Path = $__mtFile
    $__mtConfig.Run.PassThru = $true
    $__mtConfig.Output.Verbosity = $__mtVerbosity
    $__mtRun = Invoke-Pester -Configuration $__mtConfig

    $__mtFailures = [System.Collections.Generic.List[object]]::new()
    $__mtScriptAnalyzerFailures = [System.Collections.Generic.List[string]]::new()
    foreach ($__mtContainer in $__mtRun.Containers) {
        if ($__mtContainer.Result -eq 'Failed' -and $__mtContainer.ErrorRecord) {
            $__mtFailures.Add([pscustomobject]@{
                Block   = Split-Path -Leaf $__mtFile
                Name    = 'Discovery or BeforeAll/AfterAll'
                Result  = 'Failed'
                Message = ($__mtContainer.ErrorRecord | ForEach-Object { $_.DisplayErrorMessage }) -join [Environment]::NewLine
            })
        }
    }
    foreach ($__mtTest in $__mtRun.Tests) {
        if ($__mtTest.Result -notin 'Passed', 'Skipped') {
            $__mtFailures.Add([pscustomobject]@{
                Block   = $__mtTest.Block.ExpandedName
                Name    = "It $($__mtTest.ExpandedName)"
                Result  = $__mtTest.Result
                Message = $__mtTest.ErrorRecord.DisplayErrorMessage
            })
        }
        if ($__mtTest.Result -eq 'Failed' -and $__mtTest.Tag -contains 'ScriptAnalyzerRule' -and $__mtTest.StandardOutput) {
            # Formatted as text here: the analyzer's records do not survive the trip through JSON. The width is set
            # because a child process with redirected output can report a console width of 0.
            $__mtText = $__mtTest.StandardOutput | Select-Object RuleName, Severity, ScriptName, Line, Message | Format-List | Out-String -Width 4096
            $__mtScriptAnalyzerFailures.Add($__mtText.Trim())
        }
    }

    [pscustomobject]@{
        Path                   = $__mtFile
        TotalCount             = $__mtRun.TotalCount
        FailedCount            = $__mtRun.FailedCount + $__mtRun.FailedContainersCount
        Duration               = $__mtRun.Duration.TotalSeconds
        Failures               = $__mtFailures.ToArray()
        ScriptAnalyzerFailures = $__mtScriptAnalyzerFailures.ToArray()
    }
}

if ($__mtSummaryPath) {
    ConvertTo-Json -InputObject @($__mtSummaries) -Depth 5 | Set-Content -LiteralPath $__mtSummaryPath -Encoding utf8
} else {
    $__mtSummaries
}
