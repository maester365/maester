<#
.SYNOPSIS
This is the main Maester command that runs the tests and generates a report of the results.

.DESCRIPTION
Using Invoke-Maester is the easiest way to run the Pester tests and generate a report of the results.

For more advanced configuration, you can directly use the Pester module and the Export-MtHtmlReport function.

By default, Invoke-Maester runs all *.Tests.ps1 files in the current directory and all subdirectories recursively.

.EXAMPLE
Invoke-Maester

Runs all the Pester test files under the current folder and generates a report of the results in the ./test-results folder.

.EXAMPLE
Invoke-Maester ./maester-tests

Runs all the Pester tests in the folder ./tests/Maester and generates a report of the results in the default ./test-results folder.

.EXAMPLE
Invoke-Maester -Tag "CA"

Runs the Pester tests with the tag "CA" and generates a report of the results in the default ./test-results folder.

.EXAMPLE
Invoke-Maester -Tag "CA", "App"

Runs the Pester tests with the tags "CA" and "App" and generates a report of the results in the default ./test-results folder.

.EXAMPLE
Invoke-Maester -OutputFolder "./my-test-results"

Runs all the Pester tests and generates a report of the results in the ./my-test-results folder.

.EXAMPLE
Invoke-Maester -OutputHtmlFile "./test-results/TestResults.html"

Runs all the Pester tests and generates a report of the results in the specified file.

.EXAMPLE
Invoke-Maester -Path ./tests/EIDSCA

Runs all the Pester tests in the EIDSCA folder.

.EXAMPLE
Invoke-Maester -MailRecipient john@contoso.com

Runs all the Pester tests in the EIDSCA folder.


.EXAMPLE
```
$configuration = [PesterConfiguration]::Default
$configuration.Run.Path = './tests/Maester'
$configuration.Filter.Tag = 'CA'
$configuration.Filter.ExcludeTag = 'App'

Invoke-Maester -PesterConfiguration $configuration

```
Runs all the Pester tests in the EIDSCA folder.
#>

Function Invoke-Maester {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Alias("Invoke-MtMaester")]
    param (
        # Specifies one or more paths to files containing tests. The value is a path\file name or name pattern. Wildcards are permitted.
        [Parameter(Position = 0)]
        [string] $Path,

        # Only run the tests that match this tag(s).
        [string[]] $Tag,

        # Exclude the tests that match this tag(s).
        [string[]] $ExcludeTag,

        # The path to the file to save the test results in html format. The filename should include an .html extension.
        [string] $OutputHtmlFile,

        # The path to the file to save the test results in markdown format. The filename should include a .md extension.
        [string] $OutputMarkdownFile,

        # The path to the file to save the test results in json format. The filename should include a .json extension.
        [string] $OutputJsonFile,

        # The folder to save the test results. If PassThru and no -Output* is set, defaults to ./test-results.
        # If set, other -Output* parameters are ignored and all formats will be generated (markdown, html, json)
        # with a timestamp and saved in the folder.
        [string] $OutputFolder,

        # The filename to use for all the files in the output folder. e.g. 'TestResults' will generate TestResults.html, TestResults.md, TestResults.json.
        [string] $OutputFolderFileName,

        # [PesterConfiguration] object for Advanced Configuration
        # Default is New-PesterConfiguration
        # For help on each option see New-PesterConfiguration, or inspect the object it returns.
        # See [Pester Configuration](https://pester.dev/docs/usage/Configuration) for more information.
        [PesterConfiguration] $PesterConfiguration,

        # Set the Pester verbosity level. Default is 'None'.
        # None: Shows only the final summary.
        # Normal: Focus on successful containers and failed tests/blocks. Shows basic discovery information and the summary of all tests.
        # Detailed: Similar to Normal, but this level shows all blocks and tests, including successful.
        # Diagnostic: Very verbose, but useful when troubleshooting tests. This level behaves like Detailed, but also enables debug-messages.
        [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
        [string] $Verbosity = 'None',

        # Run the tests in non-interactive mode. This will prevent the test results from being opened in the default browser.
        [switch] $NonInteractive,

        # Passes the output of the Maester tests to the console.
        [switch] $PassThru,

        # Optional. The email addresses of the recipients. e.g. john@contoso.com
        # No email will be sent if this parameter is not provided.
        [string[]] $MailRecipient,

        # Uri to the detailed test results page.
        [string] $MailTestResultsUri,

        # The user id of the sender of the mail. Defaults to the current user.
        # This is required when using application permissions.
        [string] $MailUserId
    )

    function GetDefaultFileName() {
        $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
        return "TestResults-$timestamp.html"
    }

    function ValidateAndSetOutputFiles($out) {

        if (![string]::IsNullOrEmpty($out.OutputHtmlFile)) {
            if ($out.OutputFile.EndsWith(".html") -eq $false) {
                $result = "The OutputHtmlFile parameter must have an .html extension."
            }
        }
        if (![string]::IsNullOrEmpty($out.OutputMarkdownFile)) {
            if ($out.OutputMarkdownFile.EndsWith(".md") -eq $false) {
                $result = "The OutputMarkdownFile parameter must have an .md extension."
            }
        }
        if (![string]::IsNullOrEmpty($out.OutputJsonFile)) {
            if ($out.OutputJsonFile.EndsWith(".json") -eq $false) {
                $result = "The OutputJsonFile parameter must have a .json extension."
            }
        }
        if ([string]::IsNullOrEmpty($out.OutputFolder) -or `
            (!$PassThru -and [string]::IsNullOrEmpty($out.OutputFolder) -and [string]::IsNullOrEmpty($out.OutputHtmlFile) `
                    -and [string]::IsNullOrEmpty($out.OutputMarkdownFile) -and [string]::IsNullOrEmpty($out.OutputJsonFile))) {
            # No outputs specified. Set default folder.
            $out.OutputFolder = "./test-results"
        }

        if (![string]::IsNullOrEmpty($out.OutputFolder)) {
            # Create the output folder if it doesn't exist and generate filenames
            New-Item -Path $out.OutputFolder -ItemType Directory -Force | Out-Null # Create the output folder if it doesn't exist

            if ([string]::IsNullOrEmpty($out.OutputFolderFileName)) {
                # Generate a default filename
                $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
                $out.OutputFolderFileName = "TestResults-$timestamp"
            }

            $out.OutputHtmlFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).html"
            $out.OutputMarkdownFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).md"
            $out.OutputJsonFile = Join-Path $out.OutputFolder "$($out.OutputFolderFileName).json"
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
            if (Test-Path -Path "./powershell/tests/pester.ps1") {
                # Internal dev, exclude Maester's core tests
                $PesterConfiguration.Run.Path = "./tests"
            }
        }
        if ($Tag) { $PesterConfiguration.Filter.Tag = $Tag }
        if ($ExcludeTag) { $PesterConfiguration.Filter.ExcludeTag = $ExcludeTag }

        return $PesterConfiguration
    }

    $motd = @"

.___  ___.      ___       _______     _______.___________. _______ .______         ____    ____  ___      __
|   \/   |     /   \     |   ____|   /       |           ||   ____||   _  \        \   \  /   / / _ \    /_ |
|  \  /  |    /  ^  \    |  |__     |   (--------|  |----``|  |__   |  |_)  |        \   \/   / | | | |    | |
|  |\/|  |   /  /_\  \   |   __|     \   \       |  |     |   __|  |      /          \      /  | | | |    | |
|  |  |  |  /  _____  \  |  |____.----)   |      |  |     |  |____ |  |\  \----.      \    /   | |_| |  __| |
|__|  |__| /__/     \__\ |_______|_______/       |__|     |_______|| _| ``._____|       \__/     \___/  (__)_|


"@
    Write-Host -ForegroundColor Green $motd

    Clear-ModuleVariable # Reset the graph cache and urls to avoid stale data

    $isMail = $null -ne $MailRecipient
    if (!(Test-MtContext -SendMail:$isMail)) { return }

    $out = [PSCustomObject]@{
        OutputFolder         = $OutputFolder
        OutputFolderFileName = $OutputFolderFileName
        OutputHtmlFile       = $OutputHtmlFile
        OutputMarkdownFile   = $OutputMarkdownFile
        OutputJsonFile       = $OutputJsonFile
    }

    $result = ValidateAndSetOutputFiles $out

    if ($result) {
        Write-Error -Message $result
        return
    }

    $pesterConfig = GetPesterConfiguration -Path $Path -Tag $Tag -ExcludeTag $ExcludeTag -PesterConfiguration $PesterConfiguration
    Write-Verbose "Merged configuration: $($pesterConfig | ConvertTo-Json -Depth 5 -Compress)"

    Write-MtProgress "Starting tests"
    $pesterResults = Invoke-Pester -Configuration $pesterConfig

    if ($pesterResults) {

        Write-MtProgress -Activity "Processing test results" -Status "$($pesterResults.TotalCount) tests"
        $maesterResults = ConvertTo-MtMaesterResult $PesterResults

        if (![string]::IsNullOrEmpty($out.OutputJsonFile)) {
            $maesterResults | ConvertTo-Json -Depth 5 -WarningAction SilentlyContinue | Out-File -FilePath $out.OutputJsonFile -Encoding UTF8
        }

        if (![string]::IsNullOrEmpty($out.OutputMarkdownFile)) {
            Write-MtProgress -Activity "Creating markdown report" -Status $out.OutputMarkdownFile
            $output = Get-MtMarkdownReport -MaesterResults $maesterResults
            $output | Out-File -FilePath $out.OutputMarkdownFile -Encoding UTF8
        }

        if (![string]::IsNullOrEmpty($out.OutputHtmlFile)) {
            Write-MtProgress -Activity "Creating html report" -Status $out.OutputHtmlFile
            $output = Get-MtHtmlReport -MaesterResults $maesterResults
            $output | Out-File -FilePath $out.OutputHtmlFile -Encoding UTF8
            Write-Output "Measter test report generated at $($out.OutputHtmlFile)"

            if ( ( Get-MtUserInteractive ) -and ( -not $NonInteractive ) ) {
                # Open test results in default browser
                Invoke-Item $out.OutputHtmlFile | Out-Null
            }
        }

        if ($MailRecipient) {
            Write-MtProgress -Activity "Sending mail"  -Status $MailRecipient
            Send-MtMail -MaesterResults $maesterResults -Recipient $MailRecipient -TestResultsUri $MailTestResultsUri -UserId $MailUserId
        }

        if($Verbosity -eq 'None') {
            # Show final summary
            Write-Host "`nTests Passed ✅: $($pesterResults.PassedCount), " -NoNewline -ForegroundColor Green
            Write-Host "Failed ❌: $($pesterResults.FailedCount), " -NoNewline -ForegroundColor Red
            Write-Host "Skipped ⚫: $($pesterResults.SkippedCount)`n" -ForegroundColor DarkGray
        }

        Get-IsNewMaesterVersionAvailable | Out-Null

        if ($PassThru) {
            return $maesterResults
        }
    }
}