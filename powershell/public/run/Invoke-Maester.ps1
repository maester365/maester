function Invoke-Maester {
    <#
    .SYNOPSIS
    This is the main Maester command that runs the tests and generates a report of the results.

    .DESCRIPTION
    Using Invoke-Maester is the easiest way to run the Pester tests and generate a report of the results.

    For more advanced configuration, you can directly use the Pester module and the Get-MtHtmlReport function.

    By default, Invoke-Maester runs the tests that ship with Maester and the custom tests in the Custom folder of the current directory, except Active Directory tests, preview tests and long-running tests. With -Path, native custom tests (Test.*.ps1) are found anywhere under the path and Pester-format custom tests (*.Tests.ps1) only in a Custom folder. Folders are searched up to three levels deep. Active Directory tests run only after an explicit Connect-Maester -Service ActiveDirectory call succeeds.

    -Product, -Feature, -Area, -Severity and -Suite select tests by their typed attributes. Each takes a list: the values of one selector are alternatives, and different selectors must all match. They combine the same way with -Tag and -TestId. The tags of Maester 2.x, such as CA or CIS, still select the same built-in tests.

    .PARAMETER IncludeLongRunning
    Include tests that can take a long time to run in tenants with a large number of objects.

    .PARAMETER IncludePreview
    Include tests that are still being tested or are dependent on preview APIs.

    .PARAMETER NoLogo
    Do not show the Maester logo.

    .PARAMETER NonInteractive
    This will suppress the logo when Maester starts, prevent the test results from being opened in the default browser, and suppress all pretty messages.

    .PARAMETER OutputMode
    How the console output is written. Interactive draws a live status line with the result counts, a progress bar and the running test, on a terminal. Stream writes lines only, for CI and redirected output, with a progress line every 50 tests or 10 seconds and log groups and annotations on GitHub Actions and Azure Pipelines. Plain is Stream without colour or symbols. Auto, the default, picks Interactive on a terminal and Stream otherwise. The MAESTER_OUTPUT_MODE environment variable and Output.ConsoleMode in maester-config.json set it too.

    .EXAMPLE
    Invoke-Maester

    Runs the built-in tests and the custom tests in the ./Custom folder (except for Active Directory tests, preview tests and long-running tests) and generates a report of the results in the ./test-results folder.

    .EXAMPLE
    Invoke-Maester ./maester

    Runs the built-in tests and the custom tests and maester-config.json in the folder ./maester (except for Active Directory tests, preview tests and long-running tests) and generates a report of the results in the default ./test-results folder.

    .EXAMPLE
    Invoke-Maester -Tag 'CA' -IncludeLongRunning

    Runs the tests with the tag "CA" and includes long-running tests. Generates a report of the results in the default ./test-results folder.

    .EXAMPLE
    Invoke-Maester -Tag 'CA', 'App' -IncludePreview

    Runs the tests with the tags 'CA' and 'App' and includes preview tests. Generates a report of the results in the default ./test-results folder.

    .EXAMPLE
    Invoke-Maester -Product entra -Severity Critical, High

    Runs the Entra ID tests whose severity is Critical or High. Values of one selector are alternatives; different selectors must all match.

    .EXAMPLE
    Invoke-Maester -Suite cisa -Area authentication

    Runs the tests of the CISA suite that are about authentication. -Product, -Feature, -Area, -Severity and -Suite select by the typed attributes of the tests and combine with -Tag and -TestId.

    .EXAMPLE
    Invoke-Maester -OutputFolder './my-test-results'

    Runs tests and generates a report of the results in the ./my-test-results folder.

    .EXAMPLE
    Invoke-Maester -OutputHtmlFile './test-results/TestResults.html'

    Runs the tests and generates a report of the results in the specified file.

    .EXAMPLE
    Invoke-Maester -Path ./maester/Custom -SkipBuiltIn

    Runs only the custom tests in the ./maester/Custom folder.

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
    $configuration.Run.Path = './tests/Custom'
    $configuration.Filter.Tag = 'CA'
    $configuration.Filter.ExcludeTag = 'App'

    Invoke-Maester -PesterConfiguration $configuration
    ```

    Runs the built-in tests and the custom tests in the ./tests/Custom folder that include the 'CA' tag and exclude the 'App' tag.

    .EXAMPLE
    ```powershell
    Connect-Maester -Service All
    Invoke-Maester -IncludeLongRunning -IncludePreview
    ```

    Connect to all Microsoft 365 services and run their tests, including the long-running and preview tests. Active Directory tests remain excluded.

    .EXAMPLE
    ```powershell
    Connect-Maester -Service ActiveDirectory
    Invoke-Maester -Product ad -SkipGraphConnect
    ```

    Explicitly connect to Active Directory, then run the Active Directory tests without requiring a Microsoft Graph connection.

    .EXAMPLE
    Invoke-Maester -Pack ZTA

    Runs the tests that ship with Maester and the Zero Trust Assessment pack, including its long-running test, even though the pack is off by default. Other installed packs do not run.

    .EXAMPLE
    Invoke-Maester -Pack ZTA -SkipBuiltIn

    Runs only the Zero Trust Assessment pack.

    .EXAMPLE
    Invoke-Maester -AllPacks

    Runs the tests that ship with Maester and every installed pack. Without -Pack or -AllPacks, installed packs do not run.

    .EXAMPLE
    Invoke-Maester -TestId 'MT.1005', 'CISA.MS.AAD.3.*'

    Runs only test MT.1005 and the tests whose ID starts with CISA.MS.AAD.3. A test named by its exact ID runs even if it is a preview or long-running test.

    .EXAMPLE
    Invoke-Maester -ExcludeTestId 'MT.1024.*' -DryRun -PassThru

    Shows what would run, and why every other test would not, without running any test. Each test that would have run is reported as NotRun with reason DryRun. Native tests are only read; Pester-format custom tests still go through Pester discovery, which runs their BeforeDiscovery and Describe-level code.

    .EXAMPLE
    Invoke-Maester -Config ./maester-config.json, @{ Selection = @{ DefaultAction = 'Skip' }; TestSettings = @(@{ Id = 'MT.1005'; Enabled = $true }) }

    Runs with an explicit configuration instead of the config files found next to the tests. Several sources are merged left to right; here only tests enabled in TestSettings are run.

    .LINK
    https://maester.dev/docs/commands/Invoke-Maester
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Incorrectly flags ExportCsv and ExportExcel as unused')]
    [Alias('Invoke-MtMaester')]
    [CmdletBinding()]
    param (
        # The folder that holds your custom tests and configuration, or the path of one test file. Native tests are found
        # in any folder under it, Pester-format tests only in a Custom folder, up to three folder levels deep.
        # Without -Path, the Custom folder of the current folder is used. Wildcards are not expanded.
        [Parameter(Position = 0)]
        [string] $Path,

        # Only run the tests that match this tag(s).
        [string[]] $Tag,

        # Exclude the tests that match this tag(s).
        [string[]] $ExcludeTag,

        # Only run the tests of these products: keys such as entra or exchange, or an alias such as 'Entra ID'.
        # Matches a test's Product or any of its RelatedProduct values. '*' wildcards are allowed.
        [string[]] $Product,

        # Only run the tests about these features of a product, for example conditional-access. '*' wildcards are allowed.
        [string[]] $Feature,

        # Only run the tests of these security areas, for example authentication or privileged-access. '*' wildcards are allowed.
        [string[]] $Area,

        # Only run the tests with these severities: Critical, High, Medium, Low or Info.
        # A severity set for a test in the run configuration is the one that counts.
        [string[]] $Severity,

        # Only run the tests of these suites, for example Maester, CISA, CIS, EIDSCA, ORCA or AD. '*' wildcards are allowed.
        [string[]] $Suite,

        # Run these Maester Packs, by pack ID or code, for example ZTA or maester.zero-trust-assessment.
        # '*' wildcards are allowed. An installed pack runs only when it is named here (or turned on with
        # "Enabled": true in the config), so installing a pack never adds its tests to every run. A pack named
        # here runs even if it is off by default or in the config, and its long-running and preview tests run
        # too. Other packs do not run; the other tests are not affected.
        [string[]] $Pack,

        # Run every installed pack, as if each were named with -Pack, except those the config turns off.
        [switch] $AllPacks,

        # Include long running tests.
        [switch] $IncludeLongRunning,

        # Include preview tests.
        [switch] $IncludePreview,

        # The path to the file to save the test results in html format. The filename should include an .html extension.
        [string] $OutputHtmlFile,

        # Collect the affected objects: the consolidated list of objects the run touched.
        # Adds the AffectedObjects property to the results, the Affected objects page to the html report and,
        # with -OutputFolder, the <name>-affected-objects.json file (plus -affected-objects.csv with -ExportCsv).
        # Off by default because it enlarges the report; it is enabled automatically when
        # -RedactUserIdentity is used, since redaction is driven by the inventory.
        [switch] $IncludeAffectedObjects,

        # Replaces user identities (display names, user principal names and object ids) with stable
        # stable ids in the generated outputs.
        # None (default): no redaction.
        # AllOutputs: redact every generated output (html, json, markdown, csv, Excel, affected objects json and csv).
        # HtmlOnly: redact the html report only, so the machine readable exports keep the
        # real identifiers for follow up while the shareable report does not.
        [ValidateSet('None', 'HtmlOnly', 'AllOutputs')]
        [string] $RedactUserIdentity = 'None',

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

        # An optional Pester configuration for Pester-format custom tests: a [PesterConfiguration] object or a
        # hashtable. Its Run.Path, Filter.Tag, Filter.ExcludeTag and TestResult options also apply to native tests.
        # Pester is needed only when the run has Pester-format tests.
        # See [Pester Configuration](https://pester.dev/docs/usage/Configuration) for more information.
        [object] $PesterConfiguration,

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

        # If sending the report to an email recipient, provide an absolute HTTP or HTTPS Uri to the detailed test results page.
        [ValidateScript({
                $uri = $null
                if ($_ -and -not ([Uri]::TryCreate($_, [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -in @('http', 'https'))) {
                    throw 'MailTestResultsUri must be an absolute HTTP or HTTPS URI, e.g. https://contoso.com/maester/report.html'
                }
                return $true
            })]
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

        # How the console output is written: Auto, Interactive, Stream or Plain.
        [ValidateSet('Auto', 'Interactive', 'Stream', 'Plain')]
        [string] $OutputMode = 'Auto',

        # The root directory for configuration drift tracking.
        [Parameter(HelpMessage = 'Specify drift root directory, see https://maester.dev/docs/tests/MT.1060')]
        [string] $DriftRoot,

        # Only run the tests with these IDs. Exact IDs or '*' wildcards, case-insensitive.
        # A test named by its exact ID runs even if it is a preview or long-running test.
        [string[]] $TestId,

        # Do not run the tests with these IDs. Exact IDs or '*' wildcards, case-insensitive. Wins over -TestId.
        [string[]] $ExcludeTestId,

        # The run configuration: a path to a maester-config.json file, a config object (hashtable or
        # PSCustomObject), or an array of paths and objects merged left to right. When set, config files
        # next to the tests are not read. Defaults to the MAESTER_CONFIG environment variable, then to the
        # config files found from -Path.
        [object] $Config,

        # Work out which tests would run, and why the others would not, without running any test.
        # Each test that would have run is reported as NotRun with reason DryRun.
        # Pester-format custom tests still go through Pester discovery, which runs their BeforeDiscovery and Describe-level code.
        [switch] $DryRun,

        # Run only the custom tests under -Path. The tests that ship with Maester always run otherwise.
        # The packs that ship with Maester are left out too, except those named in -Pack.
        [switch] $SkipBuiltIn,

        # The pack lock file to run the installed packs from. Defaults to the MAESTER_PACK_LOCK environment
        # variable, then to the maester-packs.lock.json beside the Maester config found from -Path.
        [string] $PackLock,

        # Do not run any Maester Pack, installed or shipped with Maester.
        [switch] $SkipPack
    )

    end {
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
                if ($IncludeAffectedObjects.IsPresent) {
                    # Added only when requested so the OutputFiles of runs that do not opt in are unchanged.
                    $out | Add-Member -MemberType NoteProperty -Name OutputAffectedObjectsJsonFile -Value (Join-Path $out.OutputFolder "$($out.OutputFolderFileName)-affected-objects.json") -Force
                }

                if ($ExportCsv.IsPresent) {
                    $out.OutputCsvFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).csv"
                    if ($IncludeAffectedObjects.IsPresent) {
                        $out | Add-Member -MemberType NoteProperty -Name OutputAffectedObjectsCsvFile -Value (Join-Path $out.OutputFolder "$($out.OutputFolderFileName)-affected-objects.csv") -Force
                    }
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


        $version = Get-MtModuleVersion

        $console = Get-MtConsoleMode -Requested $OutputMode -NonInteractive:$NonInteractive
        # Windows Terminal can draw the dashboard, but a Windows console does not start in UTF-8: switch it for the run.
        if ($console.Mode -eq 'Interactive' -and -not $console.Unicode -and (Enable-MtConsoleUtf8)) {
            $console = Get-MtConsoleMode -Requested $OutputMode -NonInteractive:$NonInteractive
        }
        # Reset the graph cache and urls to avoid stale data.
        Clear-ModuleVariable
        $__MtSession.Console = $console

        # Redaction maps user identities onto their stable ids, so it needs the inventory even when
        # the caller did not ask for the Affected objects page. Collect it in that case, but only surface it
        # in the results and output files when -IncludeAffectedObjects was actually requested.
        $collectAffectedObjects = $IncludeAffectedObjects.IsPresent -or $RedactUserIdentity -ne 'None'

        if (-not $DisableTelemetry) {
            Write-Telemetry -EventName InvokeMaester
        }

        Write-MtOlderVersionWarning

        # PesterConfiguration.Run.Path is used as -Path when -Path is not given, as in 2.x.
        $callerRunPath = @(Get-MtPesterOption -Configuration $PesterConfiguration -Name 'Run.Path' | Where-Object { $_ })
        if (-not $Path -and $callerRunPath.Count -gt 0 -and $callerRunPath[0] -ne '.') {
            $Path = $callerRunPath[0]
        }

        # Where the tests come from: the built-in suites from the module, and custom tests under -Path.
        $testSource = Resolve-MtTestSource -Path $Path -SkipBuiltIn:$SkipBuiltIn

        # Stage 1: resolve the run config, with every layer including maester-config.<tenantId>.json. It is
        # resolved once, here, because everything below is derived from it: the selection, the tag rules,
        # whether the built-in tests run, and the console mode. Invoke-Maester does not connect to Graph
        # itself, so the tenant of the connection is already known.
        $configTenantId = Get-MtConfigTenantId
        try {
            $runConfig = Resolve-MtRunConfig -Path $testSource.ConfigSearchPath -Config $Config -TenantId $configTenantId
        } catch {
            Write-Error -Message $_.Exception.Message
            return
        }
        # Output.ConsoleMode in the config applies when neither -OutputMode nor MAESTER_OUTPUT_MODE chose a mode.
        $configConsoleMode = if ($runConfig.PSObject.Properties['Output'] -and $runConfig.Output -and $runConfig.Output.PSObject.Properties['ConsoleMode']) { [string]$runConfig.Output.ConsoleMode } else { $null }
        if ($OutputMode -eq 'Auto' -and -not $env:MAESTER_OUTPUT_MODE -and $configConsoleMode -in 'Interactive', 'Stream', 'Plain') {
            $console = Get-MtConsoleMode -Requested $configConsoleMode -NonInteractive:$NonInteractive
            if ($console.Mode -eq 'Interactive' -and -not $console.Unicode -and (Enable-MtConsoleUtf8)) {
                $console = Get-MtConsoleMode -Requested $configConsoleMode -NonInteractive:$NonInteractive
            }
            $__MtSession.Console = $console
        }
        # The logo comes after the config, so that Output.ConsoleMode (Plain, for example) applies to it too.
        if ( $NonInteractive.IsPresent -or $NoLogo.IsPresent ) {
            Write-Verbose "Running Maester v$Version"
        } else {
            Show-MtLogo -Console $console
        }

        if (-not $SkipBuiltIn -and $runConfig.Selection.BuiltIn -eq 'None') {
            $SkipBuiltIn = [switch]$true
            $testSource = Resolve-MtTestSource -Path $Path -SkipBuiltIn
        }
        # -SkipBuiltIn with no custom tests is fine when the run names packs: their tests are what it runs.
        $packNamed = -not $SkipPack -and ($Pack -or $AllPacks -or @($runConfig.Selection.Pack | Where-Object { $_ }).Count -gt 0 -or
            @($TestId | Where-Object { $_ -match '^MP\.[^.]+\.' }).Count -gt 0)
        if ($testSource.Error -and -not ($testSource.NoCustomTests -and $packNamed)) {
            Write-Error -Message $testSource.Error
            return
        }
        foreach ($message in $testSource.Messages) {
            if ($message.Level -eq 'Warning') { Write-Warning $message.Text }
            else { Write-Verbose $message.Text }
        }

        # A caller's PesterConfiguration filter takes part in selection: Filter.Tag is the include set when
        # -Tag is not given, and Filter.ExcludeTag adds to the exclusions instead of being overwritten.
        $callerTag = @(Get-MtPesterOption -Configuration $PesterConfiguration -Name 'Filter.Tag' | Where-Object { $_ })
        if (-not $Tag -and $callerTag.Count -gt 0) {
            $Tag = $callerTag
        }
        $callerExcludeTag = @(Get-MtPesterOption -Configuration $PesterConfiguration -Name 'Filter.ExcludeTag' | Where-Object { $_ })
        if ($callerExcludeTag.Count -gt 0) {
            $ExcludeTag = @(@($ExcludeTag) + $callerExcludeTag | Where-Object { $_ } | Select-Object -Unique)
        }

        $selection = Resolve-MtSelection -RunConfig $runConfig -Tag $Tag -ExcludeTag $ExcludeTag -TestId $TestId -ExcludeTestId $ExcludeTestId `
            -Product $Product -Feature $Feature -Area $Area -Severity $Severity -Suite $Suite -Pack $Pack `
            -IncludePreview:$IncludePreview -IncludeLongRunning:$IncludeLongRunning
        if ($SkipBuiltIn) { $selection.BuiltIn = 'None' }
        # The selectors live in $selection from here on. A test runs in a child scope of this function, so a
        # test that reads a $Severity or $Product it never set would otherwise see the value of the parameter.
        $Product = $Feature = $Area = $Severity = $Suite = $Pack = $null
        $Tag = $selection.Tag
        $ExcludeTag = $selection.ExcludeTag
        $IncludePreview = [switch]$selection.IncludePreview
        $IncludeLongRunning = [switch]$selection.IncludeLongRunning
        $autoExcludedTag = [System.Collections.Generic.List[string]]::new()

        # 'All' and 'Full' were deprecated in 2.x (where they selected nothing, because no test carries them)
        # and are removed in 3.0. Stop with the replacement instead of running an empty or unexpected selection.
        $removedTags = @(@($Tag) + @($ExcludeTag) | Where-Object { $_ -in 'All', 'Full' } | Select-Object -Unique)
        if ($removedTags.Count -gt 0) {
            throw "The '$($removedTags -join "' and '")' tag$(if ($removedTags.Count -gt 1) { 's were' } else { ' was' }) removed in Maester 3.0. Use -IncludePreview instead of 'All' and -IncludeLongRunning instead of 'Full' (or Selection.IncludePreview / Selection.IncludeLongRunning in maester-config.json)."
        }

        $isMail = $null -ne $MailRecipient

        $isTeamsChannelMessage = -not ([String]::IsNullOrEmpty($TeamId) -or [String]::IsNullOrEmpty($TeamChannelId))

        $isWebUri = -not ([String]::IsNullOrEmpty($TeamChannelWebhookUri))

        # Exclude Preview by default when neither Tag nor IncludePreview is specified.
        if (-not $Tag -and -not $IncludePreview.IsPresent) {
            $ExcludeTag += 'Preview'
            $autoExcludedTag.Add('Preview')
            Write-Verbose 'Excluding Preview tests. Use -IncludePreview to include them.'
        }

        $EffectiveIncludePreview = 'Preview' -notin @($ExcludeTag)

        if ($SkipGraphConnect) {
            if (-not $NonInteractive.IsPresent) {
                Write-Host '🔥 Skipping graph connection check' -ForegroundColor Yellow
            }
        } else {
            Test-MtContext -SendMail:$isMail -SendTeamsMessage:$isTeamsChannelMessage `
                -IncludePreview:$EffectiveIncludePreview | Out-Null
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
        if ( (-not $IncludeLongRunning.IsPresent) -and 'LongRunning' -notin $Tag -and 'CAWhatIf' -notin $Tag ) {
            $ExcludeTag += 'LongRunning'
            $autoExcludedTag.Add('LongRunning')
            Write-Verbose 'Excluding LongRunning tests. Use -IncludeLongRunning to include them.'
        }

        # The selected files, not their folders: Pester would walk a folder past the scan's depth limit and the
        # Custom folder rule, and every file it should skip would have to be listed in Run.ExcludePath.
        $pesterRunPath = @(@($testSource.BuiltInFiles) + @($testSource.CustomFiles))

        # What the engine decides for the Pester provider. A PesterConfiguration is built from it (and the
        # caller's -PesterConfiguration) only when the plan has Pester-format tests.
        $pesterFilter = [PSCustomObject]@{
            RunPath           = @($pesterRunPath)
            ExcludePath       = @()
            Tag               = @($Tag | Where-Object { $_ })
            ExcludeTag        = @($ExcludeTag | Where-Object { $_ })
            ExcludeLine       = @()
            SkipRun           = $false
            DisableTestResult = $false
        }

        # Active Directory tests are always opt-in. Supplying -Tag AD alone is not sufficient;
        # the connection must have been explicitly validated by Connect-Maester first.
        if (-not (Test-MtConnection -Service ActiveDirectory)) {
            $effectiveExcludeTags = @($pesterFilter.ExcludeTag)
            if ('AD' -notin $effectiveExcludeTags) {
                $pesterFilter.ExcludeTag = @($effectiveExcludeTags + 'AD')
                $autoExcludedTag.Add('AD')
            }
            Write-Verbose 'Excluding Active Directory tests. Run Connect-Maester -Service ActiveDirectory to include them.'
        }

        # The exclusions before any ID-based lifting: native selection applies exact-ID lifting per test itself.
        $nativeExcludeTag = @($pesterFilter.ExcludeTag | Where-Object { $_ })
        Write-Verbose "Selection: $($pesterFilter | ConvertTo-Json -Depth 3 -Compress)"

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

        # Initialize-MtSession above started a new session: give it the run config.
        $__MtSession.MaesterConfig = $runConfig

        Set-MtProgressView
        $renderer = $null
        if ($console.Mode -eq 'Interactive') {
            # The dashboard takes over the screen. With per-test lines (-Verbosity Normal and above) the
            # compact region is used instead, so the lines can scroll past it.
            $renderer = New-MtConsoleRenderer -Console $console -FullScreen:($Verbosity -eq 'None')
            $banner = Get-MtBanner -Console $console
            $renderer.SetHeader($(if ($console.Unicode) { [string[]]$banner.Lines } else { $null }), $banner.Width, $banner.Compact)
            if ($console.Unicode -and $banner.Tagline.Row -ge 0) {
                $renderer.SetHeaderTagline($banner.Tagline.Row, $banner.Tagline.Prefix, $banner.Tagline.Width, $banner.Tagline.Version, $banner.Tagline.Site, $banner.Tagline.SiteUrl)
            }
            # Once the tests start, the wordmark is at the top of the screen, with the Pace graph next to it.
            if ($console.Unicode) {
                $renderer.SetRunLogo([string[]]$banner.Band.Lines, $banner.Band.Width, $banner.Band.TaglineRow, $banner.Band.TaglinePrefix, $banner.Band.Version)
            }
            $renderer.SetPhases([string[]]@('Prepare', 'Run tests', 'Results', 'Reports'))
            Initialize-MtDashboard -Renderer $renderer -Console $console -RunConfig $runConfig -OutputJsonFile $out.OutputJsonFile -SkipVersionCheck:$SkipVersionCheck
            $renderer.StartPhase('Prepare')
            # The tenant panel and the account, while the tests are discovered; the rest follows as it is read.
            $null = Start-MtDashboardTenant -Renderer $renderer -Console $console
            # The directory is read from the session, not requested, so its panel is there from the start. It is
            # set whatever the width: the right column may only be on screen after the window is made wider.
            if ($renderer.IsFullScreen) { Set-MtDashboardDirectory -Renderer $renderer }
        }
        # While the full-screen dashboard owns the screen, a warning or error this command writes is drawn over
        # and lost when the screen is restored. Collect what Write-Warning and Write-Error write where it would
        # be shown (see Get-MtDashboardMessageDefault) and let Stop-MtConsoleOutput write it once the screen is back.
        # The lists exist before the first message: a list that -WarningVariable creates belongs to the scope of
        # the helper that wrote the message, and is lost with it.
        $mtDashboardWarnings = [System.Collections.ArrayList]::new()
        $mtDashboardErrors = [System.Collections.ArrayList]::new()
        $collectDashboardMessages = [bool]($script:__MtConsoleRenderer -and $script:__MtConsoleRenderer.IsFullScreen)
        $defaultParameterValues = $PSDefaultParameterValues
        $collectingDefaults = $null
        if ($collectDashboardMessages) {
            $collectingDefaults = Get-MtDashboardMessageDefault -Default $PSDefaultParameterValues
            $PSDefaultParameterValues = $collectingDefaults
        }
        Write-MtProgress -Activity 'Starting Maester' -Status 'Reading Maester config...' -Force
        Write-Verbose "Reading Maester config from: $($testSource.ConfigSearchPath)"
        # Resolve tenant ID for tenant-specific config lookup (maester-config.{tenantId}.json)

        # Where each row came from (Source and Suite, design appendix A.6).
        $originCache = @{}
        $fileOrigin = @{}
        foreach ($f in $testSource.BuiltInFiles) { $fileOrigin[$f] = Get-MtTestFileOrigin -File $f -Root $testSource.BuiltInRoot -BuiltIn -Cache $originCache }
        # -Path can be one test file: the suite.json files are looked for from its folder, not from the file.
        $customSuiteRoot = if ($testSource.CustomRoot -and (Test-Path -LiteralPath $testSource.CustomRoot -PathType Leaf)) { Split-Path -Path $testSource.CustomRoot -Parent } else { $testSource.CustomRoot }
        foreach ($f in $testSource.CustomFiles) { $fileOrigin[$f] = Get-MtTestFileOrigin -File $f -Root $customSuiteRoot -Cache $originCache }

        # Native tests: the built-in catalog, and custom Test.<ID>.ps1 files under the custom root.
        Write-MtProgress -Activity 'Starting Maester' -Status 'Discovering native tests...' -Force
        $nativeBuiltIn = if ($SkipBuiltIn) { @() } else { @(Get-MtTestCatalog) }
        $catalogIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($t in @(Get-MtTestCatalog)) { if ($t.Id) { $null = $catalogIds.Add($t.Id) } }
        $nativeCustom = @()
        if ($testSource.CustomRoot) {
            $customNativeFiles = @($testSource.CustomNativeFiles)
            if ($customNativeFiles.Count -gt 0) {
                $nativeCustom = @(Get-MtNativeTestInventory -Path $customNativeFiles -Root $customSuiteRoot -FrameworkPath $testSource.CustomRoot)
                # A custom native test with a built-in ID is not loaded; the built-in runs (design section 8).
                $shadowing = @($nativeCustom | Where-Object { $_.Id -and $catalogIds.Contains($_.Id) })
                if ($shadowing.Count -gt 0) {
                    Write-Warning ("These custom tests have the ID of a test that ships with Maester and were not run: $(($shadowing | ForEach-Object { $_.Id }) -join ', '). " +
                        'To change a built-in test, set its parameters in the config, or copy it under your own ID and disable the built-in.')
                    $nativeCustom = @($nativeCustom | Where-Object { -not ($_.Id -and $catalogIds.Contains($_.Id)) })
                }
                $reserved = @($nativeCustom | Where-Object { $id = $_.Id; $id -and ((Get-MtTestSchema).ReservedPrefixes | Where-Object { $id.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }) })
                if ($reserved.Count -gt 0) {
                    Write-Warning "These custom tests use an ID prefix reserved for tests shipped with Maester and for Maester Packs: $(($reserved | ForEach-Object { $_.Id }) -join ', '). Use your own prefix, for example CONTOSO."
                }
            }
        }

        # Maester Packs: the loader gate decides which packs may load before any of their code runs, then
        # their connectors join the service registry and their tests join the custom tests (Maester Packs
        # design, sections 4.4 and 6.3). A pack test is always Source = Custom and carries Package.
        $nativePack = @()
        $packSet = @()
        if (-not $SkipPack) {
            Write-MtProgress -Activity 'Starting Maester' -Status 'Checking Maester Packs...' -Force
            # A test ID of a pack (MP.<code>.<n> or MP.<code>.*) names its pack too.
            $packSelect = @($selection.Pack | Where-Object { $_ })
            if ($packSelect.Count -eq 0 -and $TestId) {
                $packSelect = @($TestId | Where-Object { $_ -match '^MP\.[^.]+\.' } | ForEach-Object { ($_ -replace '^MP\.', '') -replace '\.[^.]*$', '' } | Select-Object -Unique)
            }
            $packSet = @(Initialize-MtPackSet -PackLock $PackLock -Path $testSource.ConfigSearchPath -RunConfig $runConfig -Select $packSelect -NamedOnly:(-not $AllPacks))
            if ($SkipBuiltIn) { $packSet = @($packSet | Where-Object { -not $_.BuiltIn -or $_.Selected }) }
            $nativePack = @(Get-MtPackTestInventory -PackSet $packSet)
            # A pack test never replaces a built-in or custom test with the same ID.
            $takenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($t in @($nativeCustom) + @(Get-MtTestCatalog)) { if ($t.Id) { $null = $takenIds.Add($t.Id) } }
            $clashing = @($nativePack | Where-Object { $_.Id -and $takenIds.Contains($_.Id) })
            if ($clashing.Count -gt 0) {
                Write-Warning "These pack tests have the ID of another test and were not run: $(($clashing | ForEach-Object { "$($_.Id) ($($_.PackId))" }) -join ', ')."
                $nativePack = @($nativePack | Where-Object { -not ($_.Id -and $takenIds.Contains($_.Id)) })
            }
        } else {
            $null = Register-MtPackService -PackSet @()
            $script:__MtPackSet = @()
        }

        # Stale copies of 2.x built-in wrappers under the custom root are not run (design section 8).
        $builtInInventory = $null
        $customInventory = @()
        $superseded = $null
        if ($testSource.CustomFiles.Count -gt 0) {
            Write-MtProgress -Activity 'Starting Maester' -Status 'Checking custom tests...' -Force
            # No built-in Pester file ships once every check is native (design section 10).
            $builtInPesterFiles = @(Get-MtBuiltInPesterFile -BuiltInRoot $testSource.BuiltInRoot)
            $builtInInventory = @(if ($builtInPesterFiles.Count -gt 0) { Get-MtPesterFileInventory -Path $builtInPesterFiles })
            $customInventory = @(Get-MtPesterFileInventory -Path $testSource.CustomFiles)
            $superseded = Get-MtSupersededTest -CustomInventory $customInventory -BuiltInInventory $builtInInventory -BuiltInId @($catalogIds)
            if ($superseded.ExcludeFiles.Count -gt 0) {
                $pesterFilter.ExcludePath = @(@($pesterFilter.ExcludePath) + $superseded.ExcludeFiles | Where-Object { $_ })
            }
            if ($superseded.ExcludeLines.Count -gt 0) {
                $pesterFilter.ExcludeLine = @(@($pesterFilter.ExcludeLine) + $superseded.ExcludeLines | Where-Object { $_ })
            }
            if ($superseded.Items.Count -gt 0) {
                $files = @($superseded.Items | ForEach-Object { $_.File } | Select-Object -Unique)
                $shown = @($files | Select-Object -First 5) -join ', '
                $more = if ($files.Count -gt 5) { " and $($files.Count - 5) more" } else { '' }
                Write-Warning ("$($superseded.Items.Count) test(s) in $($files.Count) file(s) are copies of tests that now ship with Maester and were not run " +
                    "($shown$more). The tests that ship with Maester run from the module. Run Update-MaesterTests -Path '$($testSource.CustomRoot)' to remove the copies.")
            }
            $supersededKeys = @{}
            foreach ($i in $superseded.Items) { $supersededKeys["$($i.File):$($i.Line)"] = $true }
            $customInventory = @($customInventory | Where-Object { -not $supersededKeys.ContainsKey("$($_.File):$($_.Line)") })

            # A custom native test and a custom Pester test with the same ID (for example after Convert-MtTest):
            # the native test runs and the Pester test is superseded (design section 12.1).
            $nativeCustomIds = @{}
            foreach ($t in $nativeCustom) { if ($t.Id) { $nativeCustomIds[$t.Id] = $t } }
            $duplicates = @($customInventory | Where-Object { $_.Id -and $nativeCustomIds.ContainsKey($_.Id) })
            foreach ($d in $duplicates) {
                $pesterFilter.ExcludeLine = @(@($pesterFilter.ExcludeLine) + "$($d.File):$($d.Line)" | Where-Object { $_ })
            }
            if ($duplicates.Count -gt 0) {
                $duplicateKeys = @{}
                foreach ($d in $duplicates) { $duplicateKeys["$($d.File):$($d.Line)"] = $true }
                $superseded.Items = @($superseded.Items) + @($duplicates | ForEach-Object { [pscustomobject]@{ Id = $_.Id; File = $_.File; Line = $_.Line; MatchedBy = 'NativeTest' } })
                $customInventory = @($customInventory | Where-Object { -not $duplicateKeys.ContainsKey("$($_.File):$($_.Line)") })
            }
        }

        # Stage 5: ID-based selection, the typed selectors and config admission. Pester selects by tag only,
        # so tests that these rules deselect are excluded by line and reported as NotRun with a reason.
        $plan = $null
        $needsIdSelection = $selection.TestId.Count -gt 0 -or $selection.ExcludeTestId.Count -gt 0 -or (Test-MtSelectorInUse -Selection $selection) -or
            $selection.DefaultAction -eq 'Skip' -or (@($runConfig.TestSettings) | Where-Object { $_ -and $_.PSObject.Properties['Enabled'] })
        if ($needsIdSelection) {
            Write-MtProgress -Activity 'Starting Maester' -Status 'Selecting tests by ID...' -Force
            if ($null -eq $builtInInventory) { $builtInInventory = if ($testSource.BuiltInFiles.Count -gt 0) { @(Get-MtPesterFileInventory -Path $testSource.BuiltInFiles) } else { @() } }
            $inventory = @($builtInInventory | Where-Object { $_.File -in $testSource.BuiltInFiles }) + $customInventory
            $plan = Get-MtPesterSelectionPlan -Inventory $inventory -Selection $selection -RunConfig $runConfig -FileOrigin $fileOrigin
            if ($plan.ExcludeLines.Count -gt 0) {
                $pesterFilter.ExcludeLine = @(@($pesterFilter.ExcludeLine) + $plan.ExcludeLines | Where-Object { $_ })
            }
            if ($plan.LiftPreview -and $autoExcludedTag -contains 'Preview') {
                $pesterFilter.ExcludeTag = @($pesterFilter.ExcludeTag | Where-Object { $_ -ne 'Preview' })
            }
            if ($plan.LiftLongRunning -and $autoExcludedTag -contains 'LongRunning') {
                $pesterFilter.ExcludeTag = @($pesterFilter.ExcludeTag | Where-Object { $_ -ne 'LongRunning' })
            }
        }

        # IDs named in the selection or the config that match no test, Pester or native (never wildcards or
        # instances of a declared family).
        if ($needsIdSelection) {
            $nativeAll = @($nativeBuiltIn) + @($nativeCustom) + @($nativePack)
            $plan.UnknownIds = @($plan.UnknownIds | Where-Object {
                    $id = $_
                    -not ($nativeAll | Where-Object { $_.Id -eq $id -or ($_.InstanceSource -and $id -like "$($_.Id).*") })
                })
            if ($plan.UnknownIds.Count -gt 0) {
                $unknownMessage = "These test IDs match no test: $($plan.UnknownIds -join ', ')"
                switch ($selection.OnUnknownId) {
                    'Error' {
                        # Give the screen back first: the error must be readable.
                        Stop-MtConsoleOutput -Message (@($mtDashboardWarnings) + @($mtDashboardErrors))
                        Write-Error -Message "$unknownMessage. Selection.OnUnknownId is Error, so the run was stopped."; Reset-MtProgressView; return
                    }
                    'Warn' { Write-Warning $unknownMessage }
                }
            }
        }

        if ($DryRun) {
            $pesterFilter.SkipRun = $true
        }

        # Stages 2, 5 and 6 for native tests: the tenant context, then selection and applicability.
        $nativeTests = @($nativeBuiltIn) + @($nativeCustom) + @($nativePack)
        $neededServices = @($nativeTests | ForEach-Object { $_.Service } | Where-Object { $_ } | Select-Object -Unique)
        Write-MtProgress -Activity 'Starting Maester' -Status 'Reading the tenant context...' -Force
        # The dashboard shows the tenant and the services while they are read, and fills in each answer as it comes.
        $tenantStep = if ($console.Mode -eq 'Interactive') { Start-MtDashboardTenant -Renderer $renderer -Console $console -Service $(if ($neededServices) { $neededServices } else { @('Graph') }) }
        $tenantContext = Read-MtTenantContext -Service $(if ($neededServices) { $neededServices } else { @('Graph') }) -Environment $(if ($runConfig.PSObject.Properties['Environment']) { $runConfig.Environment } else { $null }) -OnStep $tenantStep
        $script:__MtDashboardTenant = $null
        $nativePlan = @()
        if ($nativeTests.Count -gt 0) {
            $nativePlan = @(Resolve-MtNativePlan -Test $nativeTests -Selection $selection -RunConfig $runConfig -TenantContext $tenantContext `
                    -IncludeTag @($pesterFilter.Tag) -ExcludeTag $nativeExcludeTag -AutoExcludedTag @($autoExcludedTag) -DryRun:$DryRun)
        }

        # The services of this run: one line in the dashboard header, and the list in the scrollback.
        $connections = @(Get-MtConnectionInfo -TenantContext $tenantContext -Plan $nativePlan)
        if ($console.Mode -eq 'Interactive') {
            # The tenant in its panel on a wide console, and the services as one line under the banner.
            $tenantPanel = $renderer.IsFullScreen -and $renderer.HasPanel('Tenant')
            Set-MtDashboardTenant -Renderer $renderer -TenantContext $tenantContext
            if ($connections.Count -gt 0 -and $renderer.IsFullScreen -and $renderer.HasPanel('Connections')) {
                # The services in their panel: which are connected, and which are not.
                $renderer.SetConnections([string[]]@($connections.Name), [bool[]]@($connections.Connected))
            } elseif ($connections.Count -gt 0) {
                # Without the panels (a narrow console, or a config that leaves them out): one line under the banner.
                $connectionLine = Format-MtConnectionInfo -Connection $connections -OneLine -NoTenant:$tenantPanel -Console $console
                $renderer.SetInfo($connectionLine.Text, $connectionLine.Length)
            }
        }
        if ($connections.Count -gt 0 -and -not $NonInteractive.IsPresent) {
            foreach ($line in @(Format-MtConnectionInfo -Connection $connections -Console $console)) { Write-MtConsoleLine $line }
        }

        # CI test results (NUnit/JUnit XML): Maester writes one file for native and Pester rows, requested
        # through Output.TestResult in the config or a caller's PesterConfiguration.TestResult (appendix A.2).
        $xmlRequest = $null
        $outputSection = if ($runConfig.PSObject.Properties['Output']) { $runConfig.Output } else { $null }
        if ($outputSection -and $outputSection.PSObject.Properties['TestResult'] -and $outputSection.TestResult -and $outputSection.TestResult.Path) {
            $xmlRequest = @{ Path = [string]$outputSection.TestResult.Path; Format = $(if ($outputSection.TestResult.Format) { [string]$outputSection.TestResult.Format } else { 'NUnitXml' }) }
            # A config file found by folder discovery (possibly in a parent folder) must not choose where
            # Maester writes: only a relative path that stays under the current folder is accepted from it.
            # -Config and MAESTER_CONFIG are the caller's own choice and may name any path.
            $explicitConfig = $PSBoundParameters.ContainsKey('Config') -or -not [string]::IsNullOrWhiteSpace($env:MAESTER_CONFIG)
            if (-not $explicitConfig) {
                $base = [System.IO.Path]::GetFullPath((Get-Location -PSProvider FileSystem).ProviderPath)
                $full = [System.IO.Path]::GetFullPath((Join-Path $base $xmlRequest.Path))
                $prefix = $base.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
                if ([System.IO.Path]::IsPathRooted($xmlRequest.Path) -or -not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Write-Warning "Output.TestResult.Path '$($xmlRequest.Path)' in $($runConfig.ConfigSource) is outside the current folder; no XML test result file is written. Use a relative path, or pass the config with -Config."
                    $xmlRequest = $null
                } else {
                    $xmlRequest.Path = $full
                }
            }
        } elseif (Get-MtPesterOption -Configuration $PesterConfiguration -Name 'TestResult.Enabled') {
            $resultPath = Get-MtPesterOption -Configuration $PesterConfiguration -Name 'TestResult.OutputPath'
            $resultFormat = Get-MtPesterOption -Configuration $PesterConfiguration -Name 'TestResult.OutputFormat'
            $xmlRequest = @{ Path = $(if ($resultPath) { [string]$resultPath } else { 'testResults.xml' }); Format = $(if ($resultFormat) { [string]$resultFormat } else { 'NUnitXml' }) }
        }
        if ($xmlRequest) {
            if ($xmlRequest.Format -in 'NUnitXml', 'NUnit2.5', 'JUnitXml') {
                $pesterFilter.DisableTestResult = $true
            } else {
                Write-Warning "Maester writes test results as NUnitXml or JUnitXml. $($xmlRequest.Format) is left to Pester and holds only the Pester-format tests."
                $xmlRequest = $null
            }
        }

        $runContext = [PSCustomObject]@{
            Selection       = $selection
            Plan            = $plan
            DryRun          = $DryRun.IsPresent
            IncludeTag      = @($pesterFilter.Tag)
            ExcludeTag      = @($pesterFilter.ExcludeTag)
            AutoExcludedTag = @($autoExcludedTag)
            FileOrigin      = $fileOrigin
            Superseded      = $superseded
            TenantContext   = $tenantContext
        }

        Write-MtProgress -Activity 'Starting Maester' -Status 'Discovering tests to run...' -Force

        # Capture is for this run's tests only; later ad-hoc Add-MtTestResultDetail calls must not collect.
        $__MtSession.IncludeAffectedObjects = $collectAffectedObjects
        $nativeRows = @()
        $nativeTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $pesterResults = $null
        try {
            # Stage 7: native tests first, then one Invoke-Pester call if the plan has Pester files.
            if ($nativePlan.Count -gt 0) {
                Set-MtConsolePhase 'Run tests'
                Write-MtProgress -Activity 'Running tests' -Status "$(@($nativePlan | Where-Object Disposition -EQ 'Run').Count) native test(s)" -Force
                # Not while the tests run: what a test writes is kept with its result.
                if ($collectDashboardMessages) { $PSDefaultParameterValues = $defaultParameterValues }
                $nativeRows = @(Invoke-MtNativePlan -Plan $nativePlan -RunConfig $runConfig -Selection $selection -Verbosity $Verbosity)
                if ($collectDashboardMessages) { $PSDefaultParameterValues = $collectingDefaults }
            }
            $nativeTimer.Stop()
            $pesterConfig = $null
            if ($pesterRunPath.Count -gt 0) {
                # Pester writes its own output: give the screen back first.
                Stop-MtConsoleOutput -Message (@($mtDashboardWarnings) + @($mtDashboardErrors))
                $mtDashboardWarnings = $null; $mtDashboardErrors = $null
                if ($collectDashboardMessages) { $PSDefaultParameterValues = $defaultParameterValues; $collectDashboardMessages = $false }
                $provider = Invoke-MtPesterProvider -Filter $pesterFilter -Configuration $PesterConfiguration -Verbosity $Verbosity
                if ($provider.Unavailable) {
                    # Pester is not installed: each Pester-format test becomes an Error row; native results stand.
                    Write-Warning 'This run includes Pester-format tests, but Pester 5.7.1 or later is not installed, so they were not run. Install it with: Install-Module Pester -MinimumVersion 5.7.1 -Scope CurrentUser'
                    $excludedFiles = @($pesterFilter.ExcludePath)
                    $excludedLines = @($pesterFilter.ExcludeLine)
                    $pesterFiles = @(@($testSource.BuiltInFiles) + @($testSource.CustomFiles) | Where-Object { $_ -notin $excludedFiles })
                    if ($pesterFiles.Count -gt 0) {
                        # Pester's tag filter, applied to the statically known tags: tests the tags leave out get no row.
                        $includeTags = @($pesterFilter.Tag | Where-Object { $_ })
                        $excludeTags = @($pesterFilter.ExcludeTag | Where-Object { $_ })
                        $tagMatch = { param($tags, $patterns) foreach ($t in @($tags)) { foreach ($pattern in $patterns) { if ($t -like $pattern) { return $true } } }; $false }
                        $nativeRows = @($nativeRows) + @(Get-MtPesterFileInventory -Path $pesterFiles | Where-Object {
                                $_.Line -and "$($_.File):$($_.Line)" -notin $excludedLines -and
                                ($includeTags.Count -eq 0 -or (& $tagMatch $_.Tags $includeTags)) -and
                                -not ($excludeTags.Count -gt 0 -and (& $tagMatch $_.Tags $excludeTags))
                            } | ForEach-Object { New-MtPesterUnavailableRow -InventoryRow $_ -Origin $fileOrigin[$_.File] })
                    }
                } else {
                    $pesterResults = $provider.Results
                    $pesterConfig = $provider.Configuration
                }
            }
        } finally {
            $__MtSession.IncludeAffectedObjects = $false
        }
        $null = Remove-MtForeignModule

        if ($pesterResults -or $nativeRows.Count -gt 0) {

            Set-MtConsolePhase 'Results'
            Write-MtProgress -Activity 'Processing test results' -Status "$(@($pesterResults.Tests).Count + $nativeRows.Count) test(s)" -Force

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

            $maesterResults = ConvertTo-MtMaesterResult -PesterResults $PesterResults -OutputFiles $out -InvokeMaesterCommand $invokeMaesterCommand -PesterConfiguration $pesterConfig -SkipVersionCheck:$SkipVersionCheck -IncludeAffectedObjects:$collectAffectedObjects -RunContext $runContext -NativeRows $nativeRows -NativeDuration $nativeTimer.Elapsed

            # 'AllOutputs' redacts every generated output, 'HtmlOnly' leaves the machine readable
            # exports intact so findings can still be traced back to the real objects.
            $redactNonHtml = $RedactUserIdentity -eq 'AllOutputs'
            $userIdentityReplacements = @{}
            if ($RedactUserIdentity -ne 'None') {
                $userIdentityReplacements = Get-MtUserIdentityReplacementMap -MaesterResults $maesterResults -IncludeSessionCache
            }

            # Drop the inventory again when it was only collected to drive redaction, so the reports
            # stay the size the caller asked for and the Affected objects page is not silently turned on.
            if ($collectAffectedObjects -and -not $IncludeAffectedObjects.IsPresent) {
                $maesterResults.PSObject.Properties.Remove('AffectedObjects')
            }

            # Csv and Excel are produced by Convert-MtResultsToFlatObject, which writes the file
            # itself, so redaction has to happen on a copy of the results rather than on the output.
            $exportResults = $maesterResults
            if ($redactNonHtml -and $userIdentityReplacements.Count -gt 0) {
                $exportResults = $maesterResults | ConvertTo-Json -Depth 5 -WarningAction SilentlyContinue |
                    ConvertTo-MtRedactedReportContent -ReplacementMap $userIdentityReplacements -JsonEncoded |
                        ConvertFrom-Json
            }

            Set-MtConsolePhase 'Reports'

            # The XML file follows -RedactUserIdentity AllOutputs like the other machine-readable exports. A
            # failure here must not stop the HTML, JSON and Markdown reports from being written.
            if ($xmlRequest -and -not $DryRun) {
                $errorsAsFailures = $outputSection -and $outputSection.PSObject.Properties['ErrorsAsFailures'] -and [bool]$outputSection.ErrorsAsFailures
                try {
                    Export-MtTestResultXml -MaesterResults $exportResults -Path $xmlRequest.Path -Format $xmlRequest.Format -ErrorsAsFailures:$errorsAsFailures -ErrorAction Stop
                } catch {
                    Write-Warning "The XML test result file '$($xmlRequest.Path)' could not be written: $($_.Exception.Message)"
                }
            }

            if (![string]::IsNullOrEmpty($out.OutputJsonFile)) {
                # Attachments keep their name and size: their content is another tool's report, embedded only in the HTML report.
                $jsonResults = $maesterResults
                if ($maesterResults.PSObject.Properties['Attachments']) {
                    $jsonResults = $maesterResults | Select-Object -Property * -ExcludeProperty Attachments
                    $jsonResults | Add-Member -MemberType NoteProperty -Name 'Attachments' -Value @($maesterResults.Attachments | Select-Object -Property * -ExcludeProperty Content)
                }
                $output = $jsonResults | ConvertTo-Json -Depth 5 -WarningAction SilentlyContinue
                if ($redactNonHtml) {
                    $output = ConvertTo-MtRedactedReportContent -Content $output -ReplacementMap $userIdentityReplacements -JsonEncoded
                }
                $output | Out-File -FilePath $out.OutputJsonFile -Encoding UTF8
            }

            if (![string]::IsNullOrEmpty($out.OutputAffectedObjectsJsonFile) -and $maesterResults.AffectedObjects) {
                Write-MtProgress -Activity 'Creating affected objects'
                $output = ConvertTo-Json -InputObject @($maesterResults.AffectedObjects) -Depth 5 -WarningAction SilentlyContinue
                if ($redactNonHtml) {
                    $output = ConvertTo-MtRedactedReportContent -Content $output -ReplacementMap $userIdentityReplacements -JsonEncoded
                }
                $output | Out-File -FilePath $out.OutputAffectedObjectsJsonFile -Encoding UTF8
            }

            if (![string]::IsNullOrEmpty($out.OutputAffectedObjectsCsvFile) -and $maesterResults.AffectedObjects) {
                $output = $maesterResults.AffectedObjects | Select-Object System, AnchorKind, Type, Id, UniqueId, DisplayName, UserPrincipalName, PortalLink,
                @{ Name = 'Tests'; Expression = { $_.Tests -join '; ' } },
                @{ Name = 'Sources'; Expression = { $_.Sources -join '; ' } } |
                    ConvertTo-Csv -NoTypeInformation
                if ($redactNonHtml) {
                    # Piped so the replacement regex is built once, not once per row.
                    $output = @($output | ConvertTo-MtRedactedReportContent -ReplacementMap $userIdentityReplacements)
                }
                $output | Out-File -FilePath $out.OutputAffectedObjectsCsvFile -Encoding UTF8
            }

            if (![string]::IsNullOrEmpty($out.OutputMarkdownFile)) {
                Write-MtProgress -Activity 'Creating markdown report'
                $output = Get-MtMarkdownReport -MaesterResults $maesterResults
                if ($redactNonHtml) {
                    $output = ConvertTo-MtRedactedReportContent -Content $output -ReplacementMap $userIdentityReplacements
                }
                $output | Out-File -FilePath $out.OutputMarkdownFile -Encoding UTF8
            }

            if (![string]::IsNullOrEmpty($out.OutputMarkdownSummaryFile)) {
                Write-MtProgress -Activity 'Creating markdown summary report'
                $output = Get-MtMarkdownSummaryReport -MaesterResults $maesterResults
                if ($redactNonHtml) {
                    $output = ConvertTo-MtRedactedReportContent -Content $output -ReplacementMap $userIdentityReplacements
                }
                $output | Out-File -FilePath $out.OutputMarkdownSummaryFile -Encoding UTF8
            }

            if (![string]::IsNullOrEmpty($out.OutputCsvFile)) {
                Write-MtProgress -Activity 'Creating CSV'
                Convert-MtResultsToFlatObject -InputObject $exportResults -CsvFilePath $out.OutputCsvFile
            }

            if (![string]::IsNullOrEmpty($out.OutputExcelFile)) {
                Write-MtProgress -Activity 'Creating Excel workbook'
                Convert-MtResultsToFlatObject -InputObject $exportResults -ExcelFilePath $out.OutputExcelFile
            }

            if (![string]::IsNullOrEmpty($out.OutputHtmlFile)) {
                Write-MtProgress -Activity 'Creating html report'
                $output = Get-MtHtmlReport -MaesterResults $maesterResults -RedactUserIdentity $RedactUserIdentity -UserIdentityReplacementMap $userIdentityReplacements
                $output | Out-File -FilePath $out.OutputHtmlFile -Encoding UTF8

                if ( ( Get-MtUserInteractive ) -and ( -not $NonInteractive ) ) {
                    # Open test results in the default browser. A headless machine can report itself as interactive
                    # but have no program to open the file, which must not fail a run whose report is already written.
                    try {
                        Invoke-Item $out.OutputHtmlFile -ErrorAction Stop | Out-Null
                    } catch {
                        Write-Warning "Could not open the report '$($out.OutputHtmlFile)': $($_.Exception.Message) Use -NonInteractive to skip opening it."
                    }
                }
            }

            if ($MailRecipient -and -not $DryRun) {
                Write-MtProgress -Activity 'Sending mail'
                Send-MtMail -MaesterResults $maesterResults -Recipient $MailRecipient -TestResultsUri $MailTestResultsUri -UserId $MailUserId
            }

            if ($TeamId -and $TeamChannelId -and -not $DryRun) {
                Write-MtProgress -Activity 'Sending Teams message'
                Send-MtTeamsMessage -MaesterResults $maesterResults -TeamId $TeamId -TeamChannelId $TeamChannelId -TestResultsUri $MailTestResultsUri
            }

            if ($TeamChannelWebhookUri -and -not $DryRun) {
                Write-MtProgress -Activity 'Sending Teams message'
                Send-MtTeamsMessage -MaesterResults $maesterResults -TeamChannelWebhookUri $TeamChannelWebhookUri -TestResultsUri $MailTestResultsUri
            }

            Write-MtProgress -Activity '🔥 Completed tests' -Completed
            # Restore the screen and write what was kept while the dashboard owned it, then the summary.
            if ($collectDashboardMessages) { $PSDefaultParameterValues = $defaultParameterValues; $collectDashboardMessages = $false }
            Stop-MtConsoleOutput -Message (@($mtDashboardWarnings) + @($mtDashboardErrors))
            $mtDashboardWarnings = $null; $mtDashboardErrors = $null
            # The run is finished and its reports are written: the summary and the annotations are display
            # only, and a failure in them must not fail the command or keep -PassThru from returning.
            try {
                if (-not $NonInteractive.IsPresent) {
                    Write-MtRunSummary -MaesterResults $maesterResults -ReportPath $out.OutputHtmlFile -Console $console -Renderer $renderer
                    # Maester runs on sponsorships: say so, with a link to maester.dev/sponsor (Output.SponsorMessage).
                    if (-not ($outputSection -and $outputSection.PSObject.Properties['SponsorMessage'] -and $outputSection.SponsorMessage -eq $false)) {
                        Write-MtSponsorMessage -Console $console
                    }
                }

                # GitHub Actions and Azure Pipelines annotations for the first Failed and Error rows (Output.CIAnnotations).
                $annotate = -not ($outputSection -and $outputSection.PSObject.Properties['CIAnnotations'] -and $outputSection.CIAnnotations -eq $false)
                if ($console.CI -and $annotate -and -not $DryRun) {
                    Write-MtCIAnnotation -Tests @($maesterResults.Tests) -Console $console
                }
            } catch {
                Write-Warning "The run summary could not be written: $($_.Exception.Message)"
            }

            if (-not $SkipVersionCheck -and 'Next' -ne $version -and -not $NonInteractive.IsPresent) {
                # Don't check version if skipped specified or running in dev or non-interactive.
                Get-IsNewMaesterVersionAvailable | Out-Null
            }

            Write-MtProgress -Activity '🔥 Completed tests' -Status "Total $($maesterResults.TotalCount) " -Completed -Force # Clear progress bar.
        }
        Reset-MtProgressView
        if ($PassThru) {
            return $maesterResults
        }
    }

    clean {
        # Always restore the console: the status line or live region of an interactive run must not
        # outlive the command, whether it returned early, failed or was stopped with Ctrl+C.
        Stop-MtConsoleOutput -Message (@($mtDashboardWarnings) + @($mtDashboardErrors))
        Restore-MtConsoleEncoding
        # The console mode is this run's: a later Invoke-MtTest works out its own.
        $__MtSession.Console = $null
    }
}
