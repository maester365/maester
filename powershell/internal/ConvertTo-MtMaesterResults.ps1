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

    function GetTestsSorted()
    {
        # Show passed and failed tests first by name then show not run tests
        $activeTests = $PesterResults.Tests | Where-Object { $_.Result -eq 'Passed' -or $_.Result -eq 'Failed' } | Sort-Object -Property Name
        $inactiveTests = $PesterResults.Tests | Where-Object { $_.Result -ne 'Passed' -and $_.Result -ne 'Failed' } | Sort-Object -Property Name

        # Convert to array and add, if not when only one object is returned it doesn't create an array with all items.
        return @($activeTests) + @($inactiveTests)
    }

    $mgContext = Get-MgContext

    $tenantId = $mgContext.TenantId
    $tenantName = GetTenantName
    $account = $mgContext.Account

    $mtTests = @()
    $sortedTests = GetTestsSorted
    foreach ($test in $sortedTests) {

        $name = $test.Name
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
            ResultDetail    = $MtTestResultDetail[$test.Name]
        }
        $mtTests += $mtTestInfo
    }

    $mtBlocks = @()
    foreach ($container in $PesterResults.Containers) {

        foreach ($block in $container.Blocks) {
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
        }
    }

    $mtTestResults = [PSCustomObject]@{
        Result       = $PesterResults.Result
        FailedCount  = $PesterResults.FailedCount
        PassedCount  = $PesterResults.PassedCount
        SkippedCount = $PesterResults.SkippedCount
        TotalCount   = $PesterResults.TotalCount
        ExecutedAt   = $PesterResults.ExecutedAt
        TenantId     = $tenantId
        TenantName   = $tenantName
        Account      = $account
        Tests        = $mtTests
        Blocks       = $mtBlocks
    }

    return $mtTestResults
}