function Invoke-Maester {
    <#
    .SYNOPSIS
    This is the main Maester command that runs the tests and generates a report of the results.

    .DESCRIPTION
    Using Invoke-Maester is the easiest way to run the Pester tests and generate a report of the results.

    For more advanced configuration, you can directly use the Pester module and the Get-MtHtmlReport function.

    By default, Invoke-Maester runs all *.Tests.ps1 files in the current directory and all subdirectories recursively, except Active Directory tests and tests tagged as LongRunning or Preview. Active Directory tests run only after an explicit Connect-Maester -Service ActiveDirectory call succeeds.

    .PARAMETER IncludeLongRunning
    Include tests that can take a long time to run in tenants with a large number of objects.

    .PARAMETER IncludePreview
    Include tests that are still being tested or are dependent on preview APIs.

    .PARAMETER NoLogo
    Do not show the Maester logo.

    .PARAMETER NonInteractive
    This will suppress the logo when Maester starts, prevent the test results from being opened in the default browser, and suppress all pretty messages.

    .EXAMPLE
    Invoke-Maester

    Runs all the test files under the current folder (except for Active Directory tests and those tagged as LongRunning or Preview) and generates a report of the results in the ./test-results folder.

    .EXAMPLE
    Invoke-Maester ./maester-tests

    Runs all the tests in the folder ./tests/Maester (except for Active Directory tests and those tagged as LongRunning or Preview) and generates a report of the results in the default ./test-results folder.

    .EXAMPLE
    Invoke-Maester -Tag 'CA' -IncludeLongRunning

    Runs the tests with the tag "CA" and includes long-running tests. Generates a report of the results in the default ./test-results folder.

    .EXAMPLE
    Invoke-Maester -Tag 'CA', 'App' -IncludePreview

    Runs the tests with the tags 'CA' and 'App' and includes preview tests. Generates a report of the results in the default ./test-results folder.

    .EXAMPLE
    Invoke-Maester -OutputFolder './my-test-results'

    Runs tests and generates a report of the results in the ./my-test-results folder.

    .EXAMPLE
    Invoke-Maester -OutputHtmlFile './test-results/TestResults.html'

    Runs the tests and generates a report of the results in the specified file.

    .EXAMPLE
    Invoke-Maester -Path ./tests/EIDSCA

    Runs tests in the EIDSCA folder.

    .EXAMPLE
    Invoke-Maester -MailRecipient john@contoso.com

    Runs the tests and sends a report of the results to an email recipient.

    .EXAMPLE
    Invoke-Maester -TeamId '00000000-0000-0000-0000-000000000000' -TeamChannelId '19%3A00000000000000000000000000000000%40thread.tacv2'

    Runs the tests and posts a summary of the results to a Teams channel.

    .EXAMPLE
    Invoke-Maester -TeamChannelWebhookUri 'https://some-url.logic.azure.com/workflows/invoke?api-version=2016-06-01'

    Runs the tests and posts a summary of the results to a Teams channel.

    .EXAMPLE
    Invoke-Maester -Verbosity Normal

    Shows results of tests as they are run, including details on failed tests.

    .EXAMPLE
    ```powershell
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = './tests/Maester'
    $configuration.Filter.Tag = 'CA'
    $configuration.Filter.ExcludeTag = 'App'

    Invoke-Maester -PesterConfiguration $configuration
    ```

    Runs Pester tests in the ./tests/Maester folder that include the 'CA' tag and exclude the 'App' tag.

    .EXAMPLE
    ```powershell
    Connect-Maester -Service All
    Invoke-Maester -IncludeLongRunning -IncludePreview
    ```

    Connect to all Microsoft 365 services and run their tests, including the long-running and preview tests. Active Directory tests remain excluded.

    .EXAMPLE
    ```powershell
    Connect-Maester -Service ActiveDirectory
    Invoke-Maester -Tag 'AD' -SkipGraphConnect
    ```

    Explicitly connect to Active Directory, then run the Active Directory tests without requiring a Microsoft Graph connection.

    .LINK
    https://maester.dev/docs/commands/Invoke-Maester
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Incorrectly flags ExportCsv and ExportExcel as unused')]
    [Alias('Invoke-MtMaester')]
    [CmdletBinding()]
    param (
        # Specifies path to files containing tests. The value is a path\file name or a name pattern. Wildcards are permitted.
        [Parameter(Position = 0)]
        [string] $Path,

        # Only run the tests that match this tag(s).
        [string[]] $Tag,

        # Exclude the tests that match this tag(s).
        [string[]] $ExcludeTag,

        # Include long running tests.
        [switch] $IncludeLongRunning,

        # Include preview tests.
        [switch] $IncludePreview,

        # The path to the file to save the test results in html format. The filename should include an .html extension.
        [string] $OutputHtmlFile,

        # The path to the file to save the test results in markdown format. The filename should include a .md extension.
        [string] $OutputMarkdownFile,

        # The path to the file to save a compact markdown summary with only result counters. The filename should include a .md extension.
        [string] $OutputMarkdownSummaryFile,

        # The path to the file to save the test results in json format. The filename should include a .json extension.
        [string] $OutputJsonFile,

        # The folder to save the test results in. If no -Output* is set, defaults to ./test-results.
        # If set, other -Output* parameters are ignored and all formats will be generated (markdown, markdown summary, html, json) with a timestamp and saved in the folder.
        [string] $OutputFolder,

        # The filename prefix to use for all the files in the output folder. e.g. 'TestResults' will generate TestResults.html, TestResults.md, TestResults.json.
        [string] $OutputFolderFileName,

        # An optional [PesterConfiguration] object for advanced configuration.
        # Default is New-PesterConfiguration
        # For help on each option see New-PesterConfiguration, or inspect the object it returns.
        # See [Pester Configuration](https://pester.dev/docs/usage/Configuration) for more information.
        [PesterConfiguration] $PesterConfiguration,

        # Set the Pester verbosity level. Default is 'None'.
        # None      : Shows only the final summary.
        # Normal    : Focus on successful containers and failed tests/blocks. Shows basic discovery information and the summary of all tests.
        # Detailed  : Similar to Normal, but this level shows all blocks and tests, including successful.
        # Diagnostic: Very verbose, but useful when troubleshooting tests. This level behaves like Detailed, but also enables debug messages.
        [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
        [string] $Verbosity = 'None',

        # Run the tests in non-interactive mode. This will prevent the test results from being opened in the default browser and suppress all pretty messages.
        [switch] $NonInteractive,

        # Passes the output of the Maester tests to the console.
        [switch] $PassThru,

        # Optional: The email addresses of the report recipients. e.g. john@contoso.com
        # No email will be sent if this parameter is not provided.
        [string[]] $MailRecipient,

        # If sending the report to an email recipient, provide a Uri to the detailed test results page.
        [string] $MailTestResultsUri,

        # The user id of the sender of the mail. Defaults to the current user.
        # This is required when using application permissions.
        [string] $MailUserId,

        # Optional: The Teams team where the test results should be posted.
        # To get the TeamId, right-click on the channel in Teams and select 'Get link to channel'. Use the value of groupId. e.g. ?groupId=<TeamId>
        [string] $TeamId,

        # Optional: The channel where the results message should be posted. e.g. 19%3A00000000000000000000000000000000%40thread.tacv2
        # To get the TeamChannelId, right-click on the channel in Teams and select 'Get link to channel'. Use the value found between channel and the channel name. e.g. /channel/<TeamChannelId>/my%20channel
        [string] $TeamChannelId,

        # Optional: The webhook Uri where the results message should be posted. e.g. https://some-url/?value=123
        # To get the Webhook Uri, right-click on the channel in Teams and select 'Workflow'. Create a workflow using the 'Post to a channel when a webhook request is received' template. Use the value after 'complete.'
        [string] $TeamChannelWebhookUri,

        # Skip the graph connection check.
        # This is used for running tests that does not require a Graph connection.
        [switch] $SkipGraphConnect,

        # Disable Telemetry
        # If set, telemetry information will not be logged.
        [switch] $DisableTelemetry,

        # Skip the version check.
        # If set, the version check will not be performed.
        [switch] $SkipVersionCheck,

        # Export the results to a CSV file.
        [Parameter(HelpMessage = 'Export the results to a CSV file. Use with -OutputFolder to specify the folder.')]
        [switch] $ExportCsv,

        # Export the results to an Excel file.
        [Parameter(HelpMessage = 'Export the results to an Excel file. Use with -OutputFolder to specify the folder.')]
        [switch] $ExportExcel,

        # Do not show the Maester logo.
        [Parameter(HelpMessage = 'Do not show the logo when starting Maester.')]
        [switch] $NoLogo,

        # The root directory for configuration drift tracking.
        [Parameter(HelpMessage = 'Specify drift root directory, see https://maester.dev/docs/tests/MT.1060')]
        [string] $DriftRoot
    )

    function GetDefaultFileName() {
        $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
        return "TestResults-$timestamp.html"
    }

    function ValidateAndSetOutputFiles($out) {
        $result = $null
        $someOutputFileHasValue = ![string]::IsNullOrEmpty($out.OutputHtmlFile) -or `
            ![string]::IsNullOrEmpty($out.OutputMarkdownFile) -or ![string]::IsNullOrEmpty($out.OutputJsonFile) -or `
            ![string]::IsNullOrEmpty($out.OutputMarkdownSummaryFile)

        if ([string]::IsNullOrEmpty($out.OutputFolder) -and !$someOutputFileHasValue) {
            # No outputs specified. Set default folder.
            $out.OutputFolder = './test-results'
        }

        if (![string]::IsNullOrEmpty($out.OutputFolder)) {
            # Create the output folder if it doesn't exist.
            New-Item -Path $out.OutputFolder -ItemType Directory -Force | Out-Null

            if ([string]::IsNullOrEmpty($out.OutputFolderFileName)) {
                # Generate a default filename.
                $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
                $out.OutputFolderFileName = "TestResults-$timestamp"
            }

            $out.OutputHtmlFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).html"
            $out.OutputMarkdownFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).md"
            $out.OutputMarkdownSummaryFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName)-summary.md"
            $out.OutputJsonFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).json"

            if ($ExportCsv.IsPresent) {
                $out.OutputCsvFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).csv"
            }
            if ($ExportExcel.IsPresent) {
                $out.OutputExcelFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).xlsx"
            }
        }

        if (![string]::IsNullOrEmpty($out.OutputHtmlFile)) {
            if ($out.OutputHtmlFile.EndsWith('.html') -eq $false) {
                $result = 'The OutputHtmlFile parameter must have an .html extension.'
            }
        }
        if (![string]::IsNullOrEmpty($out.OutputMarkdownFile)) {
            if ($out.OutputMarkdownFile.EndsWith('.md') -eq $false) {
                $result = 'The OutputMarkdownFile parameter must have an .md extension.'
            }
        }
        if (![string]::IsNullOrEmpty($out.OutputMarkdownSummaryFile)) {
            if ($out.OutputMarkdownSummaryFile.EndsWith('.md') -eq $false) {
                $result = 'The OutputMarkdownSummaryFile parameter must have an .md extension.'
            }
        }
        if (![string]::IsNullOrEmpty($out.OutputJsonFile)) {
            if ($out.OutputJsonFile.EndsWith('.json') -eq $false) {
                $result = 'The OutputJsonFile parameter must have a .json extension.'
            }
        }

        return $result
    }

    function GetPesterConfiguration($Path, $Tag, $ExcludeTag, $PesterConfiguration) {
        if (!$PesterConfiguration) {
            $PesterConfiguration = New-PesterConfiguration
        }

        $PesterConfiguration.Run.PassThru = $true
        $PesterConfiguration.Output.Verbosity = $Verbosity
        if ($Path) { $PesterConfiguration.Run.Path = $Path }
        else {
            if (Test-Path -Path './powershell/tests/pester.ps1') {
                # Internal dev, exclude Maester's core tests
                $PesterConfiguration.Run.Path = './tests'
            }
        }
        if ($Tag) { $PesterConfiguration.Filter.Tag = $Tag }
        if ($ExcludeTag) { $PesterConfiguration.Filter.ExcludeTag = $ExcludeTag }

        return $PesterConfiguration
    }

    function Add-SuffixToPath($FilePath, $Suffix) {
        if ([string]::IsNullOrEmpty($FilePath)) {
            return $FilePath
        }

        $directory = [System.IO.Path]::GetDirectoryName($FilePath)
        $name = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        $extension = [System.IO.Path]::GetExtension($FilePath)
        $fileNameWithSuffix = "$name-$Suffix$extension"

        if ([string]::IsNullOrEmpty($directory)) {
            return $fileNameWithSuffix
        }

        return (Join-Path $directory $fileNameWithSuffix)
    }

    function Get-MtInvokeMaesterCommand {
        param(
            [Parameter(Mandatory = $true)]
            [hashtable]$BoundParameters,

            [Parameter(Mandatory = $false)]
            [string]$Comment
        )

        $invokeCommand = 'Invoke-Maester'
        foreach ($param in $BoundParameters.GetEnumerator()) {
            $paramName = $param.Key
            $paramValue = $param.Value
            if ($paramValue -is [switch]) {
                if ($paramValue.IsPresent) {
                    $invokeCommand += " -$paramName"
                }
            } elseif ($paramValue -is [array]) {
                $invokeCommand += " -$paramName @('$($paramValue -join "', '")')"
            } elseif ($paramValue -is [string]) {
                $invokeCommand += " -$paramName '$paramValue'"
            } elseif ($null -ne $paramValue) {
                $invokeCommand += " -$paramName $paramValue"
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Comment)) {
            $invokeCommand += " # $Comment"
        }

        return $invokeCommand
    }

    function New-MtMergedAdForestResult {
        param(
            [Parameter(Mandatory = $true)]
            [psobject[]]$ForestResults,

            [Parameter(Mandatory = $false)]
            [string]$InvokeCommand
        )

        if (-not $ForestResults -or $ForestResults.Count -eq 0) {
            return $null
        }

        function ConvertTo-MtTimeSpan {
            param(
                [Parameter(Mandatory = $false)]
                $Value
            )

            if ($null -eq $Value) {
                return [TimeSpan]::Zero
            }

            if ($Value -is [TimeSpan]) {
                return $Value
            }

            $parsedTimeSpan = [TimeSpan]::Zero
            if ([TimeSpan]::TryParse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedTimeSpan)) {
                return $parsedTimeSpan
            }

            return [TimeSpan]::Zero
        }

        function ConvertTo-MtDateTime {
            param(
                [Parameter(Mandatory = $false)]
                $Value
            )

            if ($null -eq $Value) {
                return $null
            }

            if ($Value -is [DateTime]) {
                return $Value
            }

            $parsedDateTime = [DateTime]::MinValue
            if ([DateTime]::TryParse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDateTime)) {
                return $parsedDateTime
            }

            return $null
        }

        $mergedResult = Merge-MtMaesterResult -MaesterResults $ForestResults
        $mergedTenants = $mergedResult.Tenants
        $firstResult = @($ForestResults)[0]

        $combinedTests = foreach ($forestResult in $ForestResults) {
            foreach ($test in @($forestResult.Tests)) {
                $testCopy = $test | Select-Object *
                if ($forestResult.PSObject.Properties.Name -contains 'ADTargetServer') {
                    $testCopy | Add-Member -NotePropertyName 'ADTargetServer' -NotePropertyValue $forestResult.ADTargetServer -Force
                }
                if ($forestResult.PSObject.Properties.Name -contains 'ADForestName') {
                    $testCopy | Add-Member -NotePropertyName 'ADForestName' -NotePropertyValue $forestResult.ADForestName -Force
                }
                if ($forestResult.PSObject.Properties.Name -contains 'ADForestRootDomain') {
                    $testCopy | Add-Member -NotePropertyName 'ADForestRootDomain' -NotePropertyValue $forestResult.ADForestRootDomain -Force
                }

                $testCopy
            }
        }

        $totalCount = 0
        $passedCount = 0
        $failedCount = 0
        $errorCount = 0
        $skippedCount = 0
        $investigateCount = 0
        $notRunCount = 0
        $totalDuration = [TimeSpan]::Zero
        $userDuration = [TimeSpan]::Zero
        $discoveryDuration = [TimeSpan]::Zero
        $frameworkDuration = [TimeSpan]::Zero
        $earliestExecutedAt = $null

        foreach ($forestResult in $ForestResults) {
            $totalCount += [int]$forestResult.TotalCount
            $passedCount += [int]$forestResult.PassedCount
            $failedCount += [int]$forestResult.FailedCount
            $errorCount += [int]$forestResult.ErrorCount
            $skippedCount += [int]$forestResult.SkippedCount
            $investigateCount += [int]$forestResult.InvestigateCount
            $notRunCount += [int]$forestResult.NotRunCount

            $totalDuration += ConvertTo-MtTimeSpan -Value $forestResult.TotalDuration
            $userDuration += ConvertTo-MtTimeSpan -Value $forestResult.UserDuration
            $discoveryDuration += ConvertTo-MtTimeSpan -Value $forestResult.DiscoveryDuration
            $frameworkDuration += ConvertTo-MtTimeSpan -Value $forestResult.FrameworkDuration

            $executedAt = ConvertTo-MtDateTime -Value $forestResult.ExecutedAt
            if ($executedAt -and (($null -eq $earliestExecutedAt) -or ($executedAt -lt $earliestExecutedAt))) {
                $earliestExecutedAt = $executedAt
            }
        }

        $resultState = if ($failedCount -gt 0 -or $errorCount -gt 0) {
            'Failed'
        } elseif ($investigateCount -gt 0) {
            'Investigate'
        } elseif ($notRunCount -gt 0 -and $passedCount -eq 0 -and $failedCount -eq 0 -and $errorCount -eq 0) {
            'NotRun'
        } elseif ($skippedCount -gt 0 -and $passedCount -eq 0 -and $failedCount -eq 0 -and $errorCount -eq 0) {
            'Skipped'
        } else {
            'Passed'
        }

        $mergedResult = $firstResult | Select-Object *
        $mergedResult | Add-Member -NotePropertyName 'TenantId' -NotePropertyValue 'ActiveDirectoryMultiForest' -Force
        $mergedResult | Add-Member -NotePropertyName 'TenantName' -NotePropertyValue 'Active Directory Forests' -Force
        $mergedResult | Add-Member -NotePropertyName 'Result' -NotePropertyValue $resultState -Force
        $mergedResult | Add-Member -NotePropertyName 'TotalCount' -NotePropertyValue $totalCount -Force
        $mergedResult | Add-Member -NotePropertyName 'PassedCount' -NotePropertyValue $passedCount -Force
        $mergedResult | Add-Member -NotePropertyName 'FailedCount' -NotePropertyValue $failedCount -Force
        $mergedResult | Add-Member -NotePropertyName 'ErrorCount' -NotePropertyValue $errorCount -Force
        $mergedResult | Add-Member -NotePropertyName 'SkippedCount' -NotePropertyValue $skippedCount -Force
        $mergedResult | Add-Member -NotePropertyName 'InvestigateCount' -NotePropertyValue $investigateCount -Force
        $mergedResult | Add-Member -NotePropertyName 'NotRunCount' -NotePropertyValue $notRunCount -Force
        $mergedResult | Add-Member -NotePropertyName 'TotalDuration' -NotePropertyValue $totalDuration -Force
        $mergedResult | Add-Member -NotePropertyName 'UserDuration' -NotePropertyValue $userDuration -Force
        $mergedResult | Add-Member -NotePropertyName 'DiscoveryDuration' -NotePropertyValue $discoveryDuration -Force
        $mergedResult | Add-Member -NotePropertyName 'FrameworkDuration' -NotePropertyValue $frameworkDuration -Force
        if ($earliestExecutedAt) {
            $mergedResult | Add-Member -NotePropertyName 'ExecutedAt' -NotePropertyValue $earliestExecutedAt -Force
        }
        $mergedResult | Add-Member -NotePropertyName 'ActiveDirectoryContext' -NotePropertyValue $null -Force
        $mergedResult | Add-Member -NotePropertyName 'Tests' -NotePropertyValue @($combinedTests) -Force
        $mergedResult | Add-Member -NotePropertyName 'Tenants' -NotePropertyValue @($mergedTenants) -Force
        $mergedResult | Add-Member -NotePropertyName 'InvokeCommand' -NotePropertyValue $InvokeCommand -Force
        $mergedResult | Add-Member -NotePropertyName 'EndOfJson' -NotePropertyValue $mergedResult.EndOfJson -Force

        return $mergedResult
    }

    function Write-MtMaesterOutputs {
        param(
            [Parameter(Mandatory = $true)]
            [psobject]$MaesterResults,

            [Parameter(Mandatory = $false)]
            [int]$TestCount = 0
        )

        $jsonDepth = if ($MaesterResults.PSObject.Properties.Name -contains 'Tenants') { 7 } else { 5 }
        $jsonSerializableResult = $MaesterResults | Select-Object *

        if ($jsonSerializableResult.PSObject.Properties.Name -contains 'OutputFiles') {
            $jsonSerializableResult.PSObject.Properties.Remove('OutputFiles')
        }

        if ($jsonSerializableResult.PSObject.Properties.Name -contains 'Tenants') {
            foreach ($tenantResult in @($jsonSerializableResult.Tenants)) {
                if ($tenantResult -and $tenantResult.PSObject.Properties.Name -contains 'OutputFiles') {
                    $tenantResult.PSObject.Properties.Remove('OutputFiles')
                }
            }
        }

        Write-MtProgress -Activity 'Processing test results' -Status "$TestCount test(s)" -Force

        if (![string]::IsNullOrEmpty($out.OutputJsonFile)) {
            $jsonSerializableResult | ConvertTo-Json -Depth $jsonDepth -WarningAction SilentlyContinue | Out-File -FilePath $out.OutputJsonFile -Encoding UTF8
        }

        if (![string]::IsNullOrEmpty($out.OutputMarkdownFile)) {
            Write-MtProgress -Activity 'Creating markdown report'
            $output = Get-MtMarkdownReport -MaesterResults $MaesterResults
            $output | Out-File -FilePath $out.OutputMarkdownFile -Encoding UTF8
        }

        if (![string]::IsNullOrEmpty($out.OutputMarkdownSummaryFile)) {
            Write-MtProgress -Activity 'Creating markdown summary report'
            $output = Get-MtMarkdownSummaryReport -MaesterResults $MaesterResults
            $output | Out-File -FilePath $out.OutputMarkdownSummaryFile -Encoding UTF8
        }

        if (![string]::IsNullOrEmpty($out.OutputCsvFile)) {
            Write-MtProgress -Activity 'Creating CSV'
            Convert-MtResultsToFlatObject -InputObject $MaesterResults -CsvFilePath $out.OutputCsvFile
        }

        if (![string]::IsNullOrEmpty($out.OutputExcelFile)) {
            Write-MtProgress -Activity 'Creating Excel workbook'
            Convert-MtResultsToFlatObject -InputObject $MaesterResults -ExcelFilePath $out.OutputExcelFile
        }

        if (![string]::IsNullOrEmpty($out.OutputHtmlFile)) {
            Write-MtProgress -Activity 'Creating html report'
            $output = Get-MtHtmlReport -MaesterResults $MaesterResults
            $output | Out-File -FilePath $out.OutputHtmlFile -Encoding UTF8
            if (-not $NonInteractive.IsPresent) {
                Write-Host "🔥 Maester test report generated at $($out.OutputHtmlFile)" -ForegroundColor Green
            }

            if ( ( Get-MtUserInteractive ) -and ( -not $NonInteractive ) ) {
                # Open test results in the default browser.
                Invoke-Item $out.OutputHtmlFile | Out-Null
            }
        }

        if ($MailRecipient) {
            Write-MtProgress -Activity 'Sending mail'
            Send-MtMail -MaesterResults $MaesterResults -Recipient $MailRecipient -TestResultsUri $MailTestResultsUri -UserId $MailUserId
        }

        if ($TeamId -and $TeamChannelId) {
            Write-MtProgress -Activity 'Sending Teams message'
            Send-MtTeamsMessage -MaesterResults $MaesterResults -TeamId $TeamId -TeamChannelId $TeamChannelId -TestResultsUri $MailTestResultsUri
        }

        if ($TeamChannelWebhookUri) {
            Write-MtProgress -Activity 'Sending Teams message'
            Send-MtTeamsMessage -MaesterResults $MaesterResults -TeamChannelWebhookUri $TeamChannelWebhookUri -TestResultsUri $MailTestResultsUri
        }
    }

    function Test-IsAdOnlyRun($InputPath, $InputTags) {
        if ($InputTags -and @($InputTags).Count -gt 0) {
            return @($InputTags | Where-Object { $_ -notmatch '^AD($|[.-])' }).Count -eq 0
        }

        if ([string]::IsNullOrWhiteSpace($InputPath)) {
            return $false
        }

        return ($InputPath -match '(?i)(^|[\\/])tests([\\/])(ad|Maester[\\/]ad)([\\/]|$)')
    }

    function Get-MtAdRunContext {
        [CmdletBinding()]
        param(
            [string]$TargetServer,
            [switch]$RefreshAdState
        )

        $context = [ordered]@{
            TargetServer     = $TargetServer
            ForestName       = $null
            ForestRootDomain = $null
            DomainName       = $null
        }

        try {
            $adStateParams = @{}
            if ($RefreshAdState.IsPresent) {
                $adStateParams['Refresh'] = $true
            }

            $adState = Get-MtADDomainState @adStateParams -ErrorAction SilentlyContinue
            if ($adState) {
                if ([string]::IsNullOrWhiteSpace($context.TargetServer)) {
                    $context.TargetServer = [string]$adState.RootDSE.dnsHostName
                }

                $context.ForestName = [string]$adState.Forest.Name
                $context.ForestRootDomain = [string]$adState.Forest.RootDomain
                $context.DomainName = [string]$adState.Domain.DNSRoot
            }
        } catch {
            Write-Verbose "Failed to resolve Active Directory run context: $($_.Exception.Message)"
        }

        return [PSCustomObject]$context
    }

    $version = Get-MtModuleVersion

    if ( $NonInteractive.IsPresent -or $NoLogo.IsPresent ) {
        Write-Verbose "Running Maester v$Version"
    } else {
        # ASCII Art using style "ANSI Shadow"
        $motd = @"

███╗   ███╗ █████╗ ███████╗███████╗████████╗███████╗██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   █████╗  ██████╔╝
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══╝  ██╔══██╗
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ███████╗██║  ██║
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝ v$version

"@
        Write-Host -ForegroundColor Green $motd
    }

    # Reset the graph cache and urls to avoid stale data.
    Clear-ModuleVariable

    if (-not $DisableTelemetry) {
        Write-Telemetry -EventName InvokeMaester
    }

    $isMail = $null -ne $MailRecipient

    $isTeamsChannelMessage = -not ([String]::IsNullOrEmpty($TeamId) -or [String]::IsNullOrEmpty($TeamChannelId))

    $isWebUri = -not ([String]::IsNullOrEmpty($TeamChannelWebhookUri))

    if ($SkipGraphConnect) {
        if (-not $NonInteractive.IsPresent) {
            Write-Host '🔥 Skipping graph connection check' -ForegroundColor Yellow
        }
    } else {
        Test-MtContext -SendMail:$isMail -SendTeamsMessage:$isTeamsChannelMessage | Out-Null
    }

    # Initialize MtSession after Graph connected.
    Initialize-MtSession

    if ($isWebUri) {
        # Check if TeamChannelWebhookUri is a valid URL.
        $urlPattern = '^(https)://[^\s/$.?#].[^\s]*$'
        if (-not ($TeamChannelWebhookUri -match $urlPattern)) {
            Write-Error -Message "⚠️  Invalid Webhook URL: $TeamChannelWebhookUri"
            return
        }
    }

    $out = [PSCustomObject]@{
        OutputFolder              = $OutputFolder
        OutputFolderFileName      = $OutputFolderFileName
        OutputHtmlFile            = $OutputHtmlFile
        OutputMarkdownFile        = $OutputMarkdownFile
        OutputMarkdownSummaryFile = $OutputMarkdownSummaryFile
        OutputJsonFile            = $OutputJsonFile
        OutputCsvFile             = $null
        OutputExcelFile           = $null
    }

    $result = ValidateAndSetOutputFiles $out

    if ($result) {
        Write-Error -Message $result
        return
    }

    # Exclude LongRunning tests unless: $IncludeLongRunning is present, or LongRunning is in $Tag, or CAWhatIf is in $Tag.
    if ( (-not $IncludeLongRunning.IsPresent) -and 'LongRunning' -notin $Tag -and 'Full' -notin $Tag -and 'CAWhatIf' -notin $Tag ) {
        $ExcludeTag += 'LongRunning'
        Write-Verbose 'Excluding LongRunning tests. Use -IncludeLongRunning to include them.'
    }

    # If $Tag is not set and IncludePreview is not passed, run all tests except the ones with the "Preview" tag.
    if (-not $Tag -and -not $IncludePreview.IsPresent) {
        $ExcludeTag += 'Preview'
        Write-Verbose 'Excluding Preview tests. Use -IncludePreview to include them.'
    }

    # Include tests tagged as "LongRunning" if "Full" is included in the Tag parameter. Included for backward compatibility with deprecated tags.
    if ('Full' -in $Tag) {
        Write-Verbose 'Including long-running tests. Please use -IncludeLongRunning instead of the deprecated ''Full'' tag.'
        $ExcludeTag = $ExcludeTag | Where-Object { $_ -ne 'LongRunning' }
    }

    # Include tests tagged as "Preview" if "All" is included in the Tag parameter. Included for backward compatibility with deprecated tags.
    if ('All' -in $Tag) {
        Write-Verbose 'Including preview tests. Please use -IncludePreview instead of the deprecated ''All'' tag.'
        $ExcludeTag = $ExcludeTag | Where-Object { $_ -ne 'Preview' }
    }

    # Warn about deprecated tag usage.
    $DeprecatedTags = @('All', 'Full')
    $UsedDeprecatedTags = $DeprecatedTags | Where-Object { $Tag -contains $_ -or $ExcludeTag -contains $_ }
    if ($UsedDeprecatedTags) {
        Write-Warning "The 'All' and 'Full' tags are being deprecated and will be removed in a future release. Please use the following tags instead: `n`nLongRunning: Tests that can take a long time to run when the tenant has a large number of objects. Replaces 'Full'.`nPreview: Tests that are still being tested or are dependent on preview APIs. Replaces 'All'."
    }

    $pesterConfig = GetPesterConfiguration -Path $Path -Tag $Tag -ExcludeTag $ExcludeTag -PesterConfiguration $PesterConfiguration

    # Active Directory tests are always opt-in. Supplying -Tag AD alone is not sufficient;
    # the connection must have been explicitly validated by Connect-Maester first.
    if (-not (Test-MtConnection -Service ActiveDirectory)) {
        $effectiveExcludeTags = @($pesterConfig.Filter.ExcludeTag.Value)
        if ('AD' -notin $effectiveExcludeTags) {
            $pesterConfig.Filter.ExcludeTag = @($effectiveExcludeTags + 'AD')
        }
        Write-Verbose 'Excluding Active Directory tests. Run Connect-Maester -Service ActiveDirectory to include them.'
    }

    $Path = $pesterConfig.Run.Path.value
    Write-Verbose "Merged configuration: $($pesterConfig | ConvertTo-Json -Depth 5 -Compress)"

    if ( Test-Path -Path $Path -PathType Leaf ) {
        if ($NonInteractive.IsPresent) {
            Write-Error -Message "The path '$Path' is a file. Please provide a folder path."
        } else {
            Write-Host "The path '$Path' is a file. Please provide a folder path." -ForegroundColor Red
            Write-Host '💫 Update-MaesterTests' -NoNewline -ForegroundColor Green
            Write-Host ' → Get the latest tests built by the Maester team and community.' -ForegroundColor Yellow
        }
        return
    }

    if ( -not ( Test-Path -Path $Path -PathType Container ) ) {
        if ($NonInteractive.IsPresent) {
            Write-Error -Message "The path '$Path' does not exist."
        } else {
            Write-Host "The path '$Path' does not exist." -ForegroundColor Red
            Write-Host '💫 Update-MaesterTests' -NoNewline -ForegroundColor Green
            Write-Host ' → Get the latest tests built by the Maester team and community.' -ForegroundColor Yellow
        }
        return
    }

    if ( -not ( Get-ChildItem -Path "$Path\*.Tests.ps1" -Recurse ) ) {
        if ($NonInteractive.IsPresent) {
            Write-Error -Message "No test files found in the path '$Path'."
        } else {
            Write-Host "No test files found in the path '$Path'." -ForegroundColor Red
            Write-Host '💫 Update-MaesterTests' -NoNewline -ForegroundColor Green
            Write-Host ' → Get the latest tests built by the Maester team and community.' -ForegroundColor Yellow
        }
        return
    }

    $adTargets = @()
    if (Test-MtConnection -Service ActiveDirectory) {
        $adTargets = @(
            @($__MtSession.ADConnection.TargetServers) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
        )

        $isAdExcluded = 'AD' -in @($pesterConfig.Filter.ExcludeTag.Value)
        $isAdOnlyRun = Test-IsAdOnlyRun -InputPath $Path -InputTags $Tag

        if ($adTargets.Count -eq 1 -and -not $isAdExcluded -and $isAdOnlyRun) {
            $__MtSession.ADRunContext = Get-MtAdRunContext -TargetServer $__MtSession.ADConnection.TargetServer
            if ($__MtSession.ADRunContext.ForestName) {
                Write-Verbose "Running AD tests for forest '$($__MtSession.ADRunContext.ForestName)' via target '$($__MtSession.ADRunContext.TargetServer)'."
                Write-MtProgress -Activity 'Starting Maester' -Status "Forest: $($__MtSession.ADRunContext.ForestName)" -Force
            }
        }

        if ($adTargets.Count -gt 1 -and -not $isAdExcluded -and $isAdOnlyRun) {
            Write-Verbose "Running AD tests across $($adTargets.Count) targets from a single host."

            $originalTargetServer = $__MtSession.ADConnection.TargetServer
            $originalTargetServers = @($__MtSession.ADConnection.TargetServers)
            $originalAdRunContext = $__MtSession.ADRunContext
            $multiForestResults = @()
            $multiForestFailures = @()
            $baseFileName = if ([string]::IsNullOrWhiteSpace($OutputFolderFileName)) { "TestResults-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')" } else { $OutputFolderFileName }

            try {
                foreach ($adTarget in $adTargets) {
                    $__MtSession.ADConnection.TargetServer = $adTarget
                    $__MtSession.ADConnection.TargetServers = @($adTarget)
                    Clear-MtADCache

                    $__MtSession.ADRunContext = Get-MtAdRunContext -TargetServer $adTarget -RefreshAdState
                    $forestName = $__MtSession.ADRunContext.ForestName
                    $targetServer = if ($__MtSession.ADRunContext.TargetServer) { $__MtSession.ADRunContext.TargetServer } else { $adTarget }
                    $contextStatus = if ($forestName) { "Forest: $forestName" } else { "Target: $targetServer" }
                    $contextDescriptor = if ($forestName) { "forest '$forestName' via target '$targetServer'" } else { "target '$targetServer'" }
                    Write-Verbose "Running AD tests for $contextDescriptor"
                    Write-MtProgress -Activity 'Starting Maester' -Status "Preparing Active Directory context - $contextStatus" -Force

                    $contextSuffixSource = if ($forestName) {
                        if ($targetServer -and $targetServer -ne $forestName) {
                            "$forestName-$targetServer"
                        } else {
                            $forestName
                        }
                    } else {
                        $targetServer
                    }

                    $targetSuffix = ($contextSuffixSource -replace '[^A-Za-z0-9._-]', '_')

                    $targetParams = @{}
                    foreach ($entry in $PSBoundParameters.GetEnumerator()) {
                        $targetParams[$entry.Key] = $entry.Value
                    }

                    if (-not [string]::IsNullOrWhiteSpace($OutputFolder) -or -not [string]::IsNullOrWhiteSpace($OutputFolderFileName)) {
                        $targetParams['OutputFolderFileName'] = "$baseFileName-$targetSuffix"
                    } elseif ([string]::IsNullOrWhiteSpace($OutputHtmlFile) -and
                        [string]::IsNullOrWhiteSpace($OutputMarkdownFile) -and
                        [string]::IsNullOrWhiteSpace($OutputMarkdownSummaryFile) -and
                        [string]::IsNullOrWhiteSpace($OutputJsonFile)) {
                        $targetParams['OutputFolderFileName'] = "$baseFileName-$targetSuffix"
                    } else {
                        if (-not [string]::IsNullOrWhiteSpace($OutputHtmlFile)) {
                            $targetParams['OutputHtmlFile'] = Add-SuffixToPath -FilePath $OutputHtmlFile -Suffix $targetSuffix
                        }
                        if (-not [string]::IsNullOrWhiteSpace($OutputMarkdownFile)) {
                            $targetParams['OutputMarkdownFile'] = Add-SuffixToPath -FilePath $OutputMarkdownFile -Suffix $targetSuffix
                        }
                        if (-not [string]::IsNullOrWhiteSpace($OutputMarkdownSummaryFile)) {
                            $targetParams['OutputMarkdownSummaryFile'] = Add-SuffixToPath -FilePath $OutputMarkdownSummaryFile -Suffix $targetSuffix
                        }
                        if (-not [string]::IsNullOrWhiteSpace($OutputJsonFile)) {
                            $targetParams['OutputJsonFile'] = Add-SuffixToPath -FilePath $OutputJsonFile -Suffix $targetSuffix
                        }
                    }

                    $targetParams['PassThru'] = $true

                    try {
                        $targetResult = Invoke-Maester @targetParams -ErrorAction Stop
                        if ($targetResult) {
                            foreach ($result in @($targetResult)) {
                                $result | Add-Member -NotePropertyName 'ADTargetServer' -NotePropertyValue $targetServer -Force
                                $result | Add-Member -NotePropertyName 'ADForestName' -NotePropertyValue $forestName -Force
                                $result | Add-Member -NotePropertyName 'ADForestRootDomain' -NotePropertyValue $__MtSession.ADRunContext.ForestRootDomain -Force
                            }
                            $multiForestResults += @($targetResult)
                        }
                    } catch {
                        $failureRecord = [PSCustomObject]@{
                            TargetServer = $targetServer
                            ForestName   = $forestName
                            Error        = $_.Exception.Message
                        }
                        $multiForestFailures += $failureRecord
                        Write-Warning "Skipping AD target '$targetServer' after failure: $($_.Exception.Message)"
                    }
                }
            } finally {
                $__MtSession.ADConnection.TargetServer = $originalTargetServer
                $__MtSession.ADConnection.TargetServers = $originalTargetServers
                $__MtSession.ADRunContext = $originalAdRunContext
            }

            if ($multiForestFailures.Count -gt 0) {
                Write-Warning "Multi-forest AD run skipped $($multiForestFailures.Count) target(s) due to errors."
            }

            $combinedInvokeCommand = Get-MtInvokeMaesterCommand -BoundParameters $PSBoundParameters -Comment 'Merged multi-forest AD report'
            $mergedResults = $null
            if (@($multiForestResults).Count -gt 0) {
                $mergedResults = New-MtMergedAdForestResult -ForestResults $multiForestResults -InvokeCommand $combinedInvokeCommand
            }
            if ($mergedResults -and $multiForestFailures.Count -gt 0) {
                $mergedResults | Add-Member -NotePropertyName 'ADTargetFailures' -NotePropertyValue @($multiForestFailures) -Force
            }
            if ($mergedResults -and (
                    -not [string]::IsNullOrEmpty($out.OutputJsonFile) -or
                    -not [string]::IsNullOrEmpty($out.OutputMarkdownFile) -or
                    -not [string]::IsNullOrEmpty($out.OutputMarkdownSummaryFile) -or
                    -not [string]::IsNullOrEmpty($out.OutputCsvFile) -or
                    -not [string]::IsNullOrEmpty($out.OutputExcelFile) -or
                    -not [string]::IsNullOrEmpty($out.OutputHtmlFile))) {
                Write-MtMaesterOutputs -MaesterResults $mergedResults -TestCount @($mergedResults.Tests).Count
            }

            if ($PassThru) {
                return $multiForestResults
            }

            return
        }
    }

    # If DriftRoot is specified, set the environment variable for drift tests.
    if ($DriftRoot) {
        $DriftRoot = (Resolve-Path -Path $DriftRoot -ErrorAction SilentlyContinue).Path
        if (-not (Test-Path -Path $DriftRoot)) {
            Write-Warning "❌ The specified drift root directory '$DriftRoot' does not exist."
        } else {
            Set-Item -Path Env:\MAESTER_FOLDER_DRIFT -Value $DriftRoot
            Write-Verbose "🧪 Drift root directory set to: $DriftRoot"
        }
    } else {

        # Set the default drift root directory.
        # Set-Item -Path Env:\MAESTER_FOLDER_DRIFT -Value $(Join-Path -Path (Get-Location) -ChildPath "drift")
    }

    $maesterResults = $null

    Set-MtProgressView
    Write-MtProgress -Activity 'Starting Maester' -Status 'Reading Maester config...' -Force
    Write-Verbose "Reading Maester config from: $Path"
    # Resolve tenant ID for tenant-specific config lookup (maester-config.{tenantId}.json)
    $configTenantId = $null
    if (Test-MtConnection Graph) {
        $configTenantId = (Get-MgContext).TenantId
    }
    $__MtSession.MaesterConfig = Get-MtMaesterConfig -Path $Path -TenantId $configTenantId

    Write-MtProgress -Activity 'Starting Maester' -Status 'Discovering tests to run...' -Force

    $pesterResults = Invoke-Pester -Configuration $pesterConfig

    if ($pesterResults) {

        Write-MtProgress -Activity 'Processing test results' -Status "$($pesterResults.TotalCount) test(s)" -Force

        $invokeMaesterCommand = Get-MtInvokeMaesterCommand -BoundParameters $PSBoundParameters

        if ($__MtSession.ADRunContext) {
            $adContextParts = @()
            if (-not [string]::IsNullOrWhiteSpace($__MtSession.ADRunContext.ForestName)) {
                $adContextParts += "ADForest='$($__MtSession.ADRunContext.ForestName)'"
            }
            if (-not [string]::IsNullOrWhiteSpace($__MtSession.ADRunContext.ForestRootDomain)) {
                $adContextParts += "ADForestRoot='$($__MtSession.ADRunContext.ForestRootDomain)'"
            }
            if (-not [string]::IsNullOrWhiteSpace($__MtSession.ADRunContext.TargetServer)) {
                $adContextParts += "ADTarget='$($__MtSession.ADRunContext.TargetServer)'"
            }

            if ($adContextParts.Count -gt 0) {
                $invokeMaesterCommand += " # " + ($adContextParts -join '; ')
            }
        }

        $maesterResults = ConvertTo-MtMaesterResult -PesterResults $PesterResults -OutputFiles $out -InvokeMaesterCommand $invokeMaesterCommand -PesterConfiguration $pesterConfig -SkipVersionCheck:$SkipVersionCheck

        Write-MtMaesterOutputs -MaesterResults $maesterResults -TestCount $PesterResults.TotalCount

        if ($Verbosity -eq 'None' -and -not $NonInteractive.IsPresent) {
            # Show final summary.
            Write-Host "`nTests Passed ✅: $($maesterResults.PassedCount), " -NoNewline -ForegroundColor Green
            Write-Host "Failed ❌: $($maesterResults.FailedCount), " -NoNewline -ForegroundColor Red
            Write-Host "Investigate 🔍: $($maesterResults.InvestigateCount), " -NoNewline -ForegroundColor Magenta
            Write-Host "Skipped ⚫: $($maesterResults.SkippedCount), " -NoNewline -ForegroundColor DarkGray
            Write-Host "Error ⚠️: $($maesterResults.ErrorCount), " -NoNewline -ForegroundColor DarkGray
            Write-Host "Not Run ⚫: $($maesterResults.NotRunCount), " -NoNewline -ForegroundColor DarkGray
            Write-Host "Total ⭐: $($maesterResults.TotalCount)`n"
        }

        if (-not $SkipVersionCheck -and 'Next' -ne $version -and -not $NonInteractive.IsPresent) {
            # Don't check version if skipped specified or running in dev or non-interactive.
            Get-IsNewMaesterVersionAvailable | Out-Null
        }

        Write-MtProgress -Activity '🔥 Completed tests' -Status "Total $($pesterResults.TotalCount) " -Completed -Force # Clear progress bar.
    }
    Reset-MtProgressView
    if ($PassThru) {
        return $maesterResults
    }
}
