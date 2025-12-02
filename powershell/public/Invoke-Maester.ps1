<#
.SYNOPSIS
This is the main Maester command that runs the tests and generates a report of the results.

.DESCRIPTION
Using Invoke-Maester is the easiest way to run the Pester tests and generate a report of the results.

For more advanced configuration, you can directly use the Pester module and the Get-MtHtmlReport function.

By default, Invoke-Maester runs all *.Tests.ps1 files in the current directory and all subdirectories recursively.

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

Runs all the test files under the current folder (except for those tagged as LongRunning and Preview) and generates a report of the results in the ./test-results folder.

.EXAMPLE
Invoke-Maester ./maester-tests

Runs all the tests in the folder ./tests/Maester (except for those tagged as LongRunning and Preview) and generates a report of the results in the default ./test-results folder.

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

Connect to all tested services and run all tests, including the long-running and preview tests.

.LINK
    https://maester.dev/docs/commands/Invoke-Maester
#>
function Invoke-Maester {
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

        # The path to the file to save the test results in json format. The filename should include a .json extension.
        [string] $OutputJsonFile,

        # The folder to save the test results in. If no -Output* is set, defaults to ./test-results.
        # If set, other -Output* parameters are ignored and all formats will be generated (markdown, html, json) with a timestamp and saved in the folder.
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
        if (![string]::IsNullOrEmpty($out.OutputJsonFile)) {
            if ($out.OutputJsonFile.EndsWith('.json') -eq $false) {
                $result = 'The OutputJsonFile parameter must have a .json extension.'
            }
        }

        $someOutputFileHasValue = ![string]::IsNullOrEmpty($out.OutputHtmlFile) -or `
            ![string]::IsNullOrEmpty($out.OutputMarkdownFile) -or ![string]::IsNullOrEmpty($out.OutputJsonFile)

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
            $out.OutputJsonFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).json"

            if ($ExportCsv.IsPresent) {
                $out.OutputCsvFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).csv"
            }
            if ($ExportExcel.IsPresent) {
                $out.OutputExcelFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).xlsx"
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
        OutputFolder         = $OutputFolder
        OutputFolderFileName = $OutputFolderFileName
        OutputHtmlFile       = $OutputHtmlFile
        OutputMarkdownFile   = $OutputMarkdownFile
        OutputJsonFile       = $OutputJsonFile
        OutputCsvFile        = $null
        OutputExcelFile      = $null
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
    $__MtSession.MaesterConfig = Get-MtMaesterConfig -Path $Path

    Write-MtProgress -Activity 'Starting Maester' -Status 'Discovering tests to run...' -Force

    $pesterResults = Invoke-Pester -Configuration $pesterConfig

    if ($pesterResults) {

        Write-MtProgress -Activity 'Processing test results' -Status "$($pesterResults.TotalCount) test(s)" -Force

        # Build the Invoke-Maester command string from bound parameters
        $invokeMaesterCommand = "Invoke-Maester"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            $paramName = $param.Key
            $paramValue = $param.Value
            if ($paramValue -is [switch]) {
                if ($paramValue.IsPresent) {
                    $invokeMaesterCommand += " -$paramName"
                }
            } elseif ($paramValue -is [array]) {
                $invokeMaesterCommand += " -$paramName @('$($paramValue -join "', '")')"
            } elseif ($paramValue -is [string]) {
                $invokeMaesterCommand += " -$paramName '$paramValue'"
            } elseif ($null -ne $paramValue) {
                $invokeMaesterCommand += " -$paramName $paramValue"
            }
        }

        $maesterResults = ConvertTo-MtMaesterResult -PesterResults $PesterResults -OutputFiles $out -InvokeMaesterCommand $invokeMaesterCommand -PesterConfiguration $pesterConfig

        if (![string]::IsNullOrEmpty($out.OutputJsonFile)) {
            $maesterResults | ConvertTo-Json -Depth 5 -WarningAction SilentlyContinue | Out-File -FilePath $out.OutputJsonFile -Encoding UTF8
        }

        if (![string]::IsNullOrEmpty($out.OutputMarkdownFile)) {
            Write-MtProgress -Activity 'Creating markdown report'
            $output = Get-MtMarkdownReport -MaesterResults $maesterResults
            $output | Out-File -FilePath $out.OutputMarkdownFile -Encoding UTF8
        }

        if (![string]::IsNullOrEmpty($out.OutputCsvFile)) {
            Write-MtProgress -Activity 'Creating CSV'
            Convert-MtResultsToFlatObject -InputObject $maesterResults -CsvFilePath $out.OutputCsvFile
        }

        if (![string]::IsNullOrEmpty($out.OutputExcelFile)) {
            Write-MtProgress -Activity 'Creating Excel workbook'
            Convert-MtResultsToFlatObject -InputObject $maesterResults -ExcelFilePath $out.OutputExcelFile
        }

        if (![string]::IsNullOrEmpty($out.OutputHtmlFile)) {
            Write-MtProgress -Activity 'Creating html report'
            $output = Get-MtHtmlReport -MaesterResults $maesterResults
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
            Send-MtMail -MaesterResults $maesterResults -Recipient $MailRecipient -TestResultsUri $MailTestResultsUri -UserId $MailUserId
        }

        if ($TeamId -and $TeamChannelId) {
            Write-MtProgress -Activity 'Sending Teams message'
            Send-MtTeamsMessage -MaesterResults $maesterResults -TeamId $TeamId -TeamChannelId $TeamChannelId -TestResultsUri $MailTestResultsUri
        }

        if ($TeamChannelWebhookUri) {
            Write-MtProgress -Activity 'Sending Teams message'
            Send-MtTeamsMessage -MaesterResults $maesterResults -TeamChannelWebhookUri $TeamChannelWebhookUri -TestResultsUri $MailTestResultsUri
        }

        if ($Verbosity -eq 'None' -and -not $NonInteractive.IsPresent) {
            # Show final summary.
            Write-Host "`nTests Passed ✅: $($maesterResults.PassedCount), " -NoNewline -ForegroundColor Green
            Write-Host "Failed ❌: $($maesterResults.FailedCount), " -NoNewline -ForegroundColor Red
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
