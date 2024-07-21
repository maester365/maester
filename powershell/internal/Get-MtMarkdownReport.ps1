<#
 .Synopsis
  Generates a markdown report using the Maester test results format.

 .Description
    This markdown report can be used in GitHub actions to display the test results in a formatted way.

 .Example
    $pesterResults = Invoke-Pester -PassThru
    $maesterResults = ConvertTo-MtMaesterResult -PesterResults $pesterResults
    Get-MtMarkdownReport $maesterResults
#>

function Get-MtMarkdownReport {
    [CmdletBinding()]
    param(
        # The Maester test results returned from `Invoke-Pester -PassThru | ConvertTo-MtMaesterResult`
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults
    )
    $StatusIcon = @{
        Passed = '<img src="https://maester.dev/img/test-result/pill-pass.png" height="25" alt="Passed"/>'
        Failed = '<img src="https://maester.dev/img/test-result/pill-fail.png" height="25" alt="Failed"/>'
        NotRun = '<img src="https://maester.dev/img/test-result/pill-notrun.png" height="25" alt="Not Run"/>'
    }

    $StatusIconSm = @{
        Passed = '<img src="https://maester.dev/img/test-result/icon-pass.png" alt="Passed icon" height="18" />'
        Failed = '<img src="https://maester.dev/img/test-result/icon-fail.png" alt="Failed icon" height="18" />'
        NotRun = '<img src="https://maester.dev/img/test-result/icon-notrun.png" alt="Not Run icon" height="18" />'
    }

    function GetTestSummary() {
        $summary = @'
|Test|Status|
|-|:-:|

'@
        foreach ($test in $MaesterResults.Tests) {
            $summary += "| $($test.Name) | $($StatusIcon[$test.Result]) |`n"
        }
        return $summary
    }

    function GetTestDetails() {

        foreach ($test in $MaesterResults.Tests) {

            $details += "`n`n## $($StatusIconSm[$test.Result]) $($test.Name)`n`n`n"

            $details += $StatusIcon[$test.Result] -replace 'src', 'align="right" src'
            $details += "`n`n"

            if (![string]::IsNullOrEmpty($test.ResultDetail)) {
                # Test author has provided details
                $details += "`n`n#### Overview`n`n$($test.ResultDetail.TestDescription)"
                $details += "`n#### Test Results`n`n$($test.ResultDetail.TestResult)"
            } else {
                # Test author has not provided details, use default code in script
                $details += "`n`n#### Overview`n`n> $($test.ScriptBlock.Trim())"
                if (![string]::IsNullOrEmpty($test.ErrorRecord)) {
                    $details += "`n`n#### Reason for failure`n`n$($test.ErrorRecord)"
                }
            }

            if (![string]::IsNullOrEmpty($test.HelpUrl)) { $details += "`n`n**Learn more**: [$($test.HelpUrl)]($($test.HelpUrl))" }
            if (![string]::IsNullOrEmpty($test.Tag)) {
                $tags = '`{0}`' -f ($test.Tag -join '` `')
                $details += "`n`n**Tag**: $tags"
            }

            if (![string]::IsNullOrEmpty($test.Block)) {
                $category = '`{0}`' -f ($test.Block -join '` `')
                $details += "`n`n**Category**: $category"
            }

            if (![string]::IsNullOrEmpty($test.ScriptBlockFile)) { $details += "`n`n**Source**: ``$($test.ScriptBlockFile)``" }

            $details += "`n`n---`n`n"
        }

        return $details
    }

    $markdownFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../assets/ReportTemplate.md'
    $templateMarkdown = Get-Content -Path $markdownFilePath -Raw

    $templateMarkdown = $templateMarkdown -replace '%TenandId%', $MaesterResults.TenantId
    $templateMarkdown = $templateMarkdown -replace '%TenantName%', $MaesterResults.TenantName
    $templateMarkdown = $templateMarkdown -replace '%TenantName%', $MaesterResults.TenantVersion
    $templateMarkdown = $templateMarkdown -replace '%ModuleVersion%', $MaesterResults.CurrentVersion
    $templateMarkdown = $templateMarkdown -replace '%TestDate%', $MaesterResults.ExecutedAt
    $templateMarkdown = $templateMarkdown -replace '%TotalCount%', $MaesterResults.TotalCount
    $templateMarkdown = $templateMarkdown -replace '%PassedCount%', $MaesterResults.PassedCount
    $templateMarkdown = $templateMarkdown -replace '%FailedCount%', $MaesterResults.FailedCount
    $templateMarkdown = $templateMarkdown -replace '%NotRunCount%', $MaesterResults.NotRunCount

    $templateMarkdown = $templateMarkdown -replace '%TestSummary%', (GetTestSummary)
    $templateMarkdown = $templateMarkdown -replace '%TestDetails%', (GetTestDetails)

    return $templateMarkdown
}
