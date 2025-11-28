<#
.SYNOPSIS
  Converts Pester results to the Maester test results format which includes additional information.
#>

function ConvertTo-MtMaesterResult {
    [CmdletBinding()]
    param(
        # The Pester test results returned from Invoke-Pester -PassThru
        [Parameter(Mandatory = $true)]
        [psobject] $PesterResults,

        # Optional output files information
        [Parameter(Mandatory = $false)]
        [psobject] $OutputFiles
    )

    function GetTenantName() {
        if (Test-MtConnection Graph) {
            $org = Invoke-MtGraphRequest -RelativeUri 'organization'
            return $org.DisplayName
        } elseif (Test-MtConnection Teams) {
            $tenant = Get-CsTenant
            return $tenant.DisplayName
        } else {
            return "TenantName (not connected to Graph)"
        }
    }

    function GetTenantId() {
        if (Test-MtConnection Graph) {
            $mgContext = Get-MgContext
            return $mgContext.TenantId
        } elseif (Test-MtConnection Teams) {
            $tenant = Get-CsTenant
            return $tenant.TenantId
        } else {
            return "TenantId (not connected to Graph)"
        }
    }

    function GetAccount() {
        if (Test-MtConnection Graph) {
            $mgContext = Get-MgContext
            return $mgContext.Account
            #} elseif (Test-MtConnection Teams) {
            #    $tenant = Get-CsTenant #ToValidate: N/A
            #    return $tenant.DisplayName
        } else {
            return "Account (not connected to Graph)"
        }
    }

    function GetTestsSorted() {
        # Show passed and failed tests first by name then show not run tests
        $activeTests = $PesterResults.Tests | Where-Object { $_.Result -eq 'Passed' -or $_.Result -eq 'Failed' } | Sort-Object -Property Name
        $inactiveTests = $PesterResults.Tests | Where-Object { $_.Result -ne 'Passed' -and $_.Result -ne 'Failed' } | Sort-Object -Property Name

        # Convert to array and add, if not when only one object is returned it doesn't create an array with all items.
        return @($activeTests) + @($inactiveTests)
    }

    function GetFormattedDate($date) {
        if (!$IsCoreCLR) {
            # Prevent 5.1 date format to json issue
            return $date.ToString("o")
        } else {
            return $date
        }
    }

    function GetMaesterLatestVersion() {
        if (Get-Command 'Find-Module' -ErrorAction SilentlyContinue) {
            return (Find-Module -Name Maester).Version
        }

        return 'Unknown'
    }

    #if(Test-MtConnection Graph) { #ToValidate: Issue with -SkipGraphConnect
    #    $mgContext = Get-MgContext
    #}

    #$tenantId = $mgContext.TenantId ?? "Tenant ID (not connected to Graph)"
    $tenantId = GetTenantId
    $tenantName = GetTenantName
    #$account = $mgContext.Account ?? "Account (not connected to Graph)"
    $account = GetAccount

    $currentVersion = Get-MtModuleVersion
    $latestVersion = GetMaesterLatestVersion

    $mtTests = @()
    $sortedTests = GetTestsSorted

    $testIndex = 0

    foreach ($test in $sortedTests) {
        $testIndex++

        $name = $test.ExpandedName
        $testCustomName = $__MtSession.TestResultDetail[$test.ExpandedName].TestTitle
        if (![string]::IsNullOrEmpty($testCustomName)) {
            # Use the custom title if it's been provided.
            $name = $testCustomName
        }

        $helpUrl = ''

        $start = $name.IndexOf("See https")
        # Get the Help Url from the message and the ID
        if ($start -gt 0) {
            $helpUrl = $name.Substring($start + 4).Trim() #Strip away the "See https://maester.dev" part
            $name = $name.Substring(0, $start).Trim() #Strip away the "See https://maester.dev" part
        }


        # Find the first : and use the first part as $testId and remaining as $testTitle
        # If no : is found or if there are spaces before the first : display a warning that the test name is not in the correct format
        $titleStart = $name.IndexOf(':')
        $testId = $name # Default to the full test name if no split is found
        $testTitle = $name # Default to the full test name if no split is found

        if ($titleStart -gt 0) {
            $testId = $name.Substring(0, $titleStart).Trim()
            $testTitle = $name.Substring($titleStart + 1).Trim()
        } else {
            Write-Warning "Test name does not contain a ':' character. Please use the format 'TestId: TestTitle' → $name"
        }
        $testResultDetail = $__MtSession.TestResultDetail[$test.ExpandedName]

        # Add the other test metadata to the test result
        $testSetting = Get-MtMaesterConfigTestSetting -TestId $testId
        $severity = $testResultDetail.Severity # Default to the test result severity
        if ($testSetting -and [string]::IsNullOrEmpty($testSetting.Severity) -eq $false) {
            # Overwrite the settings if it is set in the config
            $severity = $testSetting.Severity
        }

        # Setting Result to Error, Overwriting the Skipped state
        if ($testResultDetail.TestSkipped -eq "Error" ) {
            $result = "Error"
        } elseif ((
                $test -and
                $test.ErrorRecord -and
                $test.ErrorRecord.Count -gt 0 -and
                $test.ErrorRecord[0].CategoryInfo -and
                $test.ErrorRecord[0].CategoryInfo.Reason) -and
                (@("RuntimeException","ParameterBindingValidationException","ParameterBindingException","HttpRequestException","TaskCanceledException") -Contains $test.ErrorRecord[0].CategoryInfo.Reason )) {
            Write-Verbose "Setting result=Error $($name) because: $($test.ErrorRecord[0].CategoryInfo.Reason)"
            $result = "Error"
        }
        else {
            $result = $test.Result
        }

        $timeSpanFormat = 'hh\:mm\:ss'
        $mtTestInfo = [PSCustomObject]@{
            Index           = $testIndex
            Id              = $testId
            Title           = $testTitle
            Name            = $name
            HelpUrl         = $helpUrl
            Severity        = $severity
            Tag             = @($test.Block.Tag + $test.Tag | Select-Object -Unique)
            Result          = $result
            ScriptBlock     = $test.ScriptBlock.ToString()
            ScriptBlockFile = $test.ScriptBlock.File
            ErrorRecord     = $test.ErrorRecord
            Block           = $test.Block.ExpandedName
            Duration        = $test.Duration.ToString($timeSpanFormat)
            ResultDetail    = $testResultDetail
        }
        $mtTests += $mtTestInfo
    }
    # Count all Passed, Failed, Skipped, Error, NotRun and Total results
    $Recount = [PSCustomObject]@{
        FailedCount  = 0
        PassedCount  = 0
        SkippedCount = 0
        NotRunCount  = 0
        ErrorCount   = 0
        TotalCount   = 0
    }
    $Recount.FailedCount = @($mtTests | Where-Object { $_.Result -eq 'Failed' }).Count
    $Recount.PassedCount = @($mtTests | Where-Object { $_.Result -eq 'Passed' }).Count
    $Recount.ErrorCount = @($mtTests | Where-Object { $_.Result -eq 'Error' }).Count
    $Recount.SkippedCount = @($mtTests | Where-Object { $_.Result -eq 'Skipped' }).Count
    $Recount.NotRunCount = @($mtTests | Where-Object { $_.Result -eq 'NotRun' }).Count
    $Recount.TotalCount = $mtTests.Count
    Write-Verbose "Recount: $($Recount | Out-String)"

    $mtBlocks = @()
    foreach ($container in $PesterResults.Containers) {

        foreach ($block in $container.Blocks) {
            $mtBlockInfo = $mtBlocks | Where-Object { $_.Name -eq $block.Name }
            if ($null -eq $mtBlockInfo) {
                Write-Verbose "Recalculating block: $($block.Name)"
                $mtBlockInfo = [PSCustomObject]@{
                    Name         = $block.Name
                    Result       = $block.Result
                    FailedCount  = @($mtTests | Where-Object { $_.Result -eq 'Failed' -and $_.Block -eq $block.name }).Count
                    PassedCount  = @($mtTests | Where-Object { $_.Result -eq 'Passed' -and $_.Block -eq $block.name }).Count
                    ErrorCount   = @($mtTests | Where-Object { $_.Result -eq 'Error' -and $_.Block -eq $block.name }).Count
                    SkippedCount = @($mtTests | Where-Object { $_.Result -eq 'Skipped' -and $_.Block -eq $block.name }).Count
                    NotRunCount  = @($mtTests | Where-Object { $_.Result -eq 'NotRun' -and $_.Block -eq $block.name }).Count
                    TotalCount   = @($mtTests | Where-Object { $_.Block -eq $block.name }).Count
                    Tag          = $block.Tag
                }
                $mtBlocks += $mtBlockInfo
            }
            else {
                # We already seen and counted all blocks
            }
        }
    }

    $mtTestResults = [PSCustomObject]@{
        Result            = $PesterResults.Result
        FailedCount       = $Recount.FailedCount
        PassedCount       = $Recount.PassedCount
        ErrorCount        = $Recount.ErrorCount
        SkippedCount      = $Recount.SkippedCount
        NotRunCount       = $Recount.NotRunCount
        TotalCount        = $Recount.TotalCount
        ExecutedAt        = GetFormattedDate($PesterResults.ExecutedAt)
        TotalDuration     = $PesterResults.Duration.ToString($timeSpanFormat)
        UserDuration      = $PesterResults.UserDuration.ToString($timeSpanFormat)
        DiscoveryDuration = $PesterResults.DiscoveryDuration.ToString($timeSpanFormat)
        FrameworkDuration = $PesterResults.FrameworkDuration.ToString($timeSpanFormat)
        TenantId          = $tenantId
        TenantName        = $tenantName
        Account           = $account
        CurrentVersion    = $currentVersion
        LatestVersion     = $latestVersion
        Tests             = $mtTests
        Blocks            = $mtBlocks
    }

    # Add output files information if provided
    if ($OutputFiles) {
        $mtTestResults | Add-Member -MemberType NoteProperty -Name 'OutputFiles' -Value $OutputFiles
    }

    return $mtTestResults
}
