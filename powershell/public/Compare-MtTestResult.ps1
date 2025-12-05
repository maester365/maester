<#
.SYNOPSIS
    Compares Maester test result JSON files
.DESCRIPTION
    Will compare the most recent two test result JSON outputs from prior Invoke-Maester
    runs, or will accept any two test result JSON files and provide the tests that have changed.
.EXAMPLE
    Compare-MtTestResult -BaseDir .\test-results
.EXAMPLE
    $tests = @{
        NewTest   = (Get-Content .\test-results\TestResults-2024-05-21-182925.json | ConvertFrom-Json)
        PriorTest = (Get-Content .\test-results\TestResults-2024-05-20-182925.json | ConvertFrom-Json)
    }
    Compare-MtTestResult @tests

.LINK
    https://maester.dev/docs/commands/Compare-MtTestResult
#>
function Compare-MtTestResult {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "Directory", Position = 0, Mandatory = $true)]
        # Path to folder where test results are located. The two newest results will be compared.
        $BaseDir,
        [Parameter(ParameterSetName = "Files", Position = 0, Mandatory = $true)]
        # Path to the previous test result JSON-file to be used as a reference.
        $PriorTest,
        [Parameter(ParameterSetName = "Files", Position = 1, Mandatory = $true)]
        # Path to the newer test result JSON-file to be used as the current result.
        $NewTest
    )

    if (-not ($NewTest -and $PriorTest)) {
        $reportProperties = @("Account", "Blocks", "CurrentVersion", "ExecutedAt", "ErrorCount", "FailedCount", "InvestigateCount", "LatestVersion", "NotRunCount", "PassedCount", "Result", "SkippedCount", "TenantId", "TenantName", "Tests", "TotalCount")
        $reports = @()
        $files = Get-ChildItem "$BaseDir\TestResults-*.json"
        Write-Verbose "Found $($files.Count) TestResults-*.json files in $BaseDir"
        foreach ($file in $files) {
            $report = Get-Content $file | ConvertFrom-Json
            if (-not (Compare-Object $reportProperties $report.PSObject.Properties.Name)) {
                Write-Verbose "Report properties match, adding to collection"
                $reports += $report
            }
        }
        $reports = $reports | Sort-Object ExecutedAt -Descending
        $tenants = $reports | Group-Object TenantId
        $reportsToCompare = @()
        foreach ($tenant in $tenants) {
            if ($tenant.Count -ge 2) {
                $obj = [PSCustomObject]@{
                    tenant  = $tenant.Name
                    reports = $tenant.Group | Select-Object -First 2
                }
                $reportsToCompare += $obj
            }
        }

        foreach ($reportToCompare in $reportsToCompare) {
            Compare-MtTestResult -NewTest $reportToCompare.reports[0] -PriorTest $reportToCompare.reports[1]
        }
    } else {
        $compareTests = ($NewTest.Tests + $PriorTest.Tests) | Group-Object Name, Result
        $testDeltas = $compareTests | Where-Object { $_.Count -lt 2 } | Select-Object -Unique @{n = "Name"; e = { $_.Group.Name } }
        $results = @()
        foreach ($testDelta in $testDeltas) {
            $result = [PSCustomObject]@{
                Name       = $testDelta.Name
                PriorState = ($PriorTest.Tests | Where-Object { $_.Name -eq $testDelta.Name }).Result
                NewState   = ($NewTest.Tests | Where-Object { $_.Name -eq $testDelta.Name }).Result
            }
            $results += $result
        }
        return $results
    }
}