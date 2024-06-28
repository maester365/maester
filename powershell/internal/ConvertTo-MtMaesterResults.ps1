<#
.SYNOPSIS
  Converts Pester results to the Maester test results format which includes additional information.
#>

function ConvertTo-MtMaesterResult {
    [CmdletBinding()]
    param(
        # The Pester test results returned from Invoke-Pester -PassThru
        [Parameter(Mandatory = $true)]
        [psobject] $PesterResults
    )

    function GetTenantName() {
        $org = Invoke-MtGraphRequest -RelativeUri 'organization'
        return $org.DisplayName
    }

    function GetTestsSorted() {
        # Show passed and failed tests first by name then show not run tests
        $activeTests = $PesterResults.Tests | Where-Object { $_.Result -eq 'Passed' -or $_.Result -eq 'Failed' } | Sort-Object -Property Name
        $inactiveTests = $PesterResults.Tests | Where-Object { $_.Result -ne 'Passed' -and $_.Result -ne 'Failed' } | Sort-Object -Property Name

        # Convert to array and add, if not when only one object is returned it doesn't create an array with all items.
        return @($activeTests) + @($inactiveTests)
    }

    function GetFormattedDate($date) {
        if(!$IsCoreCLR) { # Prevent 5.1 date format to json issue
            return $date.ToString("o")
        }
        else {
            return $date
        }
    }

    $mgContext = Get-MgContext

    $tenantId = $mgContext.TenantId
    $tenantName = GetTenantName
    $account = $mgContext.Account

    $currentVersion = ((Get-Module -Name Maester).Version | Select-Object -Last 1).ToString()
    $latestVersion = (Find-Module -Name Maester).Version

    $mtTests = @()
    $sortedTests = GetTestsSorted

    foreach ($test in $sortedTests) {

        $name = $test.ExpandedName
        $helpUrl = ''

        $start = $name.IndexOf("See https")
        # Get the Help Url from the message and the ID
        if ($start -gt 0) {
            $helpUrl = $name.Substring($start + 4).Trim() #Strip away the "See https://maester.dev" part
            $name = $name.Substring(0, $start).Trim() #Strip away the "See https://maester.dev" part
        }
        $mtTestInfo = [PSCustomObject]@{
            Name            = $name
            HelpUrl         = $helpUrl
            Tag             = $test.Block.Tag
            Result          = $test.Result
            ScriptBlock     = $test.ScriptBlock.ToString()
            ScriptBlockFile = $test.ScriptBlock.File
            ErrorRecord     = $test.ErrorRecord
            Block           = $test.Block.Name
            ResultDetail    = $__MtSession.TestResultDetail[$test.ExpandedName]
        }
        $mtTests += $mtTestInfo
    }

    $mtBlocks = @()
    foreach ($container in $PesterResults.Containers) {

        foreach ($block in $container.Blocks) {
            $mtBlockInfo = $mtBlocks | Where-Object { $_.Name -eq $block.Name }
            if ($null -eq $mtBlockInfo) {
                $mtBlockInfo = [PSCustomObject]@{
                    Name         = $block.Name
                    Result       = $block.Result
                    FailedCount  = $block.FailedCount
                    PassedCount  = $block.PassedCount
                    SkippedCount = $block.SkippedCount
                    NotRunCount  = $block.NotRunCount
                    TotalCount   = $block.TotalCount
                    Tag          = $block.Tag
                }
                $mtBlocks += $mtBlockInfo
            } else {
                $mtBlockInfo.FailedCount += $block.FailedCount
                $mtBlockInfo.PassedCount += $block.PassedCount
                $mtBlockInfo.SkippedCount += $block.SkippedCount
                $mtBlockInfo.NotRunCount += $block.NotRunCount
                $mtBlockInfo.TotalCount += $block.TotalCount
            }
        }
    }

    $mtTestResults = [PSCustomObject]@{
        Result         = $PesterResults.Result
        FailedCount    = $PesterResults.FailedCount
        PassedCount    = $PesterResults.PassedCount
        SkippedCount   = $PesterResults.SkippedCount
        TotalCount     = $PesterResults.TotalCount
        ExecutedAt     = GetFormattedDate($PesterResults.ExecutedAt)
        TenantId       = $tenantId
        TenantName     = $tenantName
        Account        = $account
        CurrentVersion = $currentVersion
        LatestVersion  = $latestVersion
        Tests          = $mtTests
        Blocks         = $mtBlocks
    }

    return $mtTestResults
}