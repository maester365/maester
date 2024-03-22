<#
.SYNOPSIS
Runs the Pester tests and generates a report of the results.

.DESCRIPTION
This helper script runs Pester tests and generates a report of the results in HTML format.

Using Invoke-Maester is the easiest way to run the Pester tests and generate a report of the results.

For more advanced configuration, you can directly use the Pester module and the Export-MtHtmlReport function.

By default, Invoke-Maester runs all *.Tests.ps1 files in the current directory and all subdirectories recursively.

.EXAMPLE
Invoke-Maester

Runs all the Pester tests and generates a report of the results in the default ./test-results folder.

.EXAMPLE
Invoke-Maester ./tests/Maester

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
Invoke-Maester -OutputFile "./test-results/TestResults.html"

Runs all the Pester tests and generates a report of the results in the specified file.

.EXAMPLE
Invoke-Maester -Path ./tests/EIDSCA

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
    [Alias('Invoke-MtMaester')]
    [CmdletBinding(DefaultParameterSetName = 'OutputFolder')]
    param (
        # Specifies one or more paths to files containing tests. The value is a path\file name or name pattern. Wildcards are permitted.
        [Parameter(Position = 0, ParameterSetName = "OutputFile")]
        [Parameter(Position = 0, ParameterSetName = "OutputFolder")]
        [string] $Path,

        # Only run the tests that match this tag(s).
        [Parameter(ParameterSetName = "OutputFile")]
        [Parameter(ParameterSetName = "OutputFolder")]
        [string[]] $Tag,

        # Exclude the tests that match this tag(s).
        [Parameter(ParameterSetName = "OutputFile")]
        [Parameter(ParameterSetName = "OutputFolder")]
        [string[]] $ExcludeTag,

        # The path to the file to save the test results in html format. The filename should include an .html extension.
        [Parameter(ParameterSetName = "Advanced")]
        [Parameter(Mandatory = $true, ParameterSetName = "OutputFile")]
        [string] $OutputFile,

        # The folder to save the test results. Default is "./test-results". The file name will be automatically generated with the current date and time.
        [Parameter(ParameterSetName = "Advanced")]
        [Parameter(ParameterSetName = "OutputFolder")]
        [string] $OutputFolder = "./test-results",

        # [PesterConfiguration] object for Advanced Configuration
        # Default is New-PesterConfiguration
        # For help on each option see New-PesterConfiguration, or inspect the object it returns.
        # See [Pester Configuration](https://pester.dev/docs/usage/Configuration) for more information.
        [Parameter(ParameterSetName = "OutputFile")]
        [Parameter(ParameterSetName = "OutputFolder")]
        [Parameter(Mandatory = $true, ParameterSetName = "Advanced")]
        [PesterConfiguration] $PesterConfiguration
    )

    function GetDefaultFileName() {
        $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
        return "TestResults-$timestamp.html"
    }

    # Validates the parameter sets and returns the output file path
    function GetOutputFilePath() {
        if ($PSCmdlet.ParameterSetName -eq "OutputFile") {
            if ($OutputFile.EndsWith(".html") -eq $false) {
                Write-Error "The OutputFile parameter must include an .html extension."
                exit
            }
            $htmlFileName = $OutputFile
        } else {
            New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null # Create the output folder if it doesn't exist

            $htmlFileName = Join-Path $OutputFolder (GetDefaultFileName)
        }
        return $htmlFileName
    }

    function GetPesterConfiguration() {
        if (!$PesterConfiguration) {
            $PesterConfiguration = New-PesterConfiguration
        }

        $PesterConfiguration.Run.PassThru = $true
        if ($Path) { $PesterConfiguration.Run.Path = $Path }
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
    Write-Host -ForegroundColor Green -Object $motd

    if (!(Get-MgContext)) {
        Write-Error "Not connected to Microsoft Graph. Please use 'Connect-MtGraph'.`nFor more information, use 'Get-Help Connect-MtGraph'."
        return
    }

    $htmlFileName = GetOutputFilePath

    Clear-MtGraphCache # Reset the cache to avoid stale data

    $pesterConfig = GetPesterConfiguration
    $pesterResults = Invoke-Pester -Configuration $pesterConfig

    if ($pesterResults) {
        Export-MtHtmlReport -PesterResults $pesterResults -OutputHtmlPath $htmlFileName # Export test results to HTML
        Write-Output "Test file generated at $htmlFileName"

        if ([Environment]::UserInteractive -and !([Environment]::GetCommandLineArgs() |? {$_ -like '-NonI*'})) {
            # Open test results in default browser
            Invoke-Item $htmlFileName
        }
    }
}