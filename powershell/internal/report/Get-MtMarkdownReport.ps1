function Get-MtMarkdownReport {
    <#
    .Synopsis
     Generates a markdown report using the Maester test results format.

    .Description
       This markdown report can be used in GitHub actions to display the test results in a formatted way.

       When the results have the defender's path (Steps), the report starts with "Do these first": the first five
       steps that are ready, in rank order, each with its failed tests, and one line that counts the steps that are
       blocked and those whose prerequisites need checking first.

    .Example
       $pesterResults = Invoke-Pester -PassThru
       $maesterResults = ConvertTo-MtMaesterResult -PesterResults $pesterResults
       Get-MtMarkdownReport $maesterResults
    #>
    [CmdletBinding()]
    param(
        # The Maester test results returned from `Invoke-Pester -PassThru | ConvertTo-MtMaesterResult`
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults
    )
    $StatusIcon = @{
        Passed      = '<img src="https://maester.dev/img/test-result/pill-pass.png" height="25" alt="Passed"/>'
        Failed      = '<img src="https://maester.dev/img/test-result/pill-fail.png" height="25" alt="Failed"/>'
        NotRun      = '<img src="https://maester.dev/img/test-result/pill-notrun.png" height="25" alt="Not Run"/>'
        Skipped     = '<img src="https://maester.dev/img/test-result/pill-notrun.png" height="25" alt="Skipped"/>'
        Investigate = '<img src="https://maester.dev/img/test-result/pill-investigate.png" height="25" alt="Investigate"/>'
        Error       = '<img src="https://maester.dev/img/test-result/pill-fail.png" height="25" alt="Error"/>'
    }

    $StatusIconSm = @{
        Passed      = '✅'
        Failed      = '❌'
        NotRun      = '❔'
        Skipped     = '🚫'
        Investigate = '🔍'
        Error       = '⚠️'
    }

    $ResultDisplayName = @{
        Passed      = 'Passed'
        Failed      = 'Failed'
        NotRun      = 'Not Run'
        Skipped     = 'Skipped'
        Investigate = 'Investigate'
        Error       = 'Error'
    }

    $SeverityIcon = @{
        Critical = '🔴 Critical'
        High     = '🟠 High'
        Medium   = '🟡 Medium'
        Low      = '🟢 Low'
        Info     = 'ℹ️ Info'
    }

    function GetSeverityText($severity) {
        if ($severity -and $SeverityIcon.ContainsKey($severity)) { return $SeverityIcon[$severity] } else { return $severity }
    }

    # The report is several MB for a full run: build it with a StringBuilder, because appending to a string
    # with += copies the whole string each time.
    function GetTestSummary() {
        $summary = [System.Text.StringBuilder]::new(@'
|Test|Severity|Status|
|-|:-:|:-:|

'@)
        foreach ($test in $MaesterResults.Tests) {
            $severityText = GetSeverityText $test.Severity
            [void]$summary.Append("| $($test.Name) | $severityText | $($StatusIcon[$test.Result]) |`n")
        }
        return $summary.ToString()
    }

    function GetTestDetails() {
        $details = [System.Text.StringBuilder]::new()

        foreach ($test in $MaesterResults.Tests) {

            [void]$details.Append("### $($StatusIconSm[$test.Result]) $($test.Name)`n`n")

            $severityText = GetSeverityText $test.Severity
            $resultName = if ($ResultDisplayName.ContainsKey($test.Result)) { $ResultDisplayName[$test.Result] } else { $test.Result }
            [void]$details.Append("**Severity:** $severityText &nbsp;&nbsp;&nbsp;&nbsp; **Status:** $($StatusIconSm[$test.Result]) $resultName`n`n")

            if (![string]::IsNullOrEmpty($test.ResultDetail)) {
                # Test author has provided details
                [void]$details.Append("#### Overview`n`n$($test.ResultDetail.TestDescription)`n`n")
                [void]$details.Append("#### Test Results`n`n$($test.ResultDetail.TestResult)`n`n")
            } elseif (![string]::IsNullOrEmpty($test.ScriptBlock)) {
                # Test author has not provided details, use default code in script
                # make sure we do not execute the code in the script block!
                $cleanedScriptBlock = $test.ScriptBlock.ToString() -replace '%\w+%', '' -replace '\$_', '€_' # or show me how I can make it not execute the $_ thing
                [void]$details.Append("#### Overview`n`n``````ps1`n$cleanedScriptBlock`n```````n`n")
                if (![string]::IsNullOrEmpty($test.ErrorRecord)) {
                    [void]$details.Append("#### Reason for failure`n`n$($test.ErrorRecord)`n`n")
                }
            }

            if (![string]::IsNullOrEmpty($test.HelpUrl)) { [void]$details.Append("**Learn more**: [$($test.HelpUrl)]($($test.HelpUrl))`n`n") }
            if (![string]::IsNullOrEmpty($test.Tag)) {
                $tags = '`{0}`' -f ($test.Tag -join '` `')
                [void]$details.Append("**Tag**: $tags`n`n")
            }

            if (![string]::IsNullOrEmpty($test.Block)) {
                $category = '`{0}`' -f ($test.Block -join '` `')
                [void]$details.Append("**Category**: $category`n`n")
            }

            if (![string]::IsNullOrEmpty($test.ScriptBlockFile)) { [void]$details.Append("**Source**: ``$($test.ScriptBlockFile)```n`n") }

            [void]$details.Append("---`n`n")
        }

        return $details.ToString()
    }

    # The defender's path: the first five Ready steps with their failed tests, and the count of the others.
    function GetDefendersPath() {
        if (-not ($MaesterResults.PSObject.Properties['Steps'] -and $MaesterResults.Steps)) { return '' }
        $steps = @($MaesterResults.Steps | Sort-Object -Property { [int]$_.Rank })
        $ready = @($steps | Where-Object { $_.Readiness -eq 'Ready' })
        $blocked = @($steps | Where-Object { $_.Readiness -eq 'Blocked' }).Count
        $unconfirmed = @($steps | Where-Object { $_.Readiness -eq 'Unconfirmed' }).Count
        $titles = @{}
        foreach ($test in @($MaesterResults.Tests)) { if ($test.Id -and -not $titles.ContainsKey([string]$test.Id)) { $titles[[string]$test.Id] = [string]$test.Title } }
        $text = [System.Text.StringBuilder]::new("## Do these first`n`n")
        if ($ready.Count -eq 0) {
            [void]$text.Append("No step of the defender's path is ready to start.`n`n")
        }
        $number = 0
        foreach ($step in @($ready | Select-Object -First 5)) {
            $number++
            [void]$text.Append("$number. **$($step.Title)** (``$($step.Id)``)`n")
            foreach ($t in @($step.Tests | Where-Object { $_.Result -eq 'Failed' })) {
                $title = if ($titles.ContainsKey([string]$t.Id)) { ": $($titles[[string]$t.Id])" } else { '' }
                [void]$text.Append("   - $($StatusIconSm['Failed']) $($t.Id)$title`n")
            }
            if ($step.Measure -and $null -ne $step.Measure.Share) {
                [void]$text.Append("   - $($step.Measure.Share)% of $($step.Measure.Total) meet it, $($step.Measure.MinimumShare)% needed`n")
            }
        }
        if ($number -gt 0) { [void]$text.Append("`n") }
        $blockedText = if ($blocked -eq 1) { '1 step is blocked' } else { "$blocked steps are blocked" }
        $checkText = if ($unconfirmed -eq 1) { '1 step has prerequisites to check first' } else { "$unconfirmed steps have prerequisites to check first" }
        [void]$text.Append("$blockedText, and $checkText.`n`n")
        return $text.ToString()
    }

    $markdownFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../../assets/ReportTemplate.md'
    $templateMarkdown = Get-Content -Path $markdownFilePath -Raw

    # Execute functions first so they don't mess with the markdown template
    $textSummary = GetTestSummary
    $textDetails = GetTestDetails
    $textDefendersPath = GetDefendersPath

    $templateMarkdown = $templateMarkdown -replace '%TenandId%', $MaesterResults.TenantId
    $templateMarkdown = $templateMarkdown -replace '%TenantName%', $MaesterResults.TenantName
    $templateMarkdown = $templateMarkdown -replace '%TenantName%', $MaesterResults.TenantVersion
    $templateMarkdown = $templateMarkdown -replace '%ModuleVersion%', $MaesterResults.CurrentVersion
    $templateMarkdown = $templateMarkdown -replace '%TestDate%', $MaesterResults.ExecutedAt
    $templateMarkdown = $templateMarkdown -replace '%TotalCount%', $MaesterResults.TotalCount
    $templateMarkdown = $templateMarkdown -replace '%PassedCount%', $MaesterResults.PassedCount
    $templateMarkdown = $templateMarkdown -replace '%FailedCount%', $MaesterResults.FailedCount
    $templateMarkdown = $templateMarkdown -replace '%InvestigateCount%', $MaesterResults.InvestigateCount
    $templateMarkdown = $templateMarkdown -replace '%SkippedCount%', $MaesterResults.SkippedCount
    $templateMarkdown = $templateMarkdown -replace '%NotRunCount%', $MaesterResults.NotRunCount

    # A literal replacement: step titles are text, not a regular expression's replacement pattern.
    $templateMarkdown = $templateMarkdown.Replace('%DefendersPath%', $textDefendersPath)
    $templateMarkdown = $templateMarkdown -replace '%TestSummary%', $textSummary
    $templateMarkdown = $templateMarkdown -replace '%TestDetails%', $textDetails

    return $templateMarkdown
}
