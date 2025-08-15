function Get-TestInventory {
<#
.SYNOPSIS
    Discover Pester test inventory (without executing tests) and output structured objects.

.DESCRIPTION
    Uses Pester discovery (SkipRun) to enumerate all tests under the provided path and returns a list of objects containing:

        TestName      - Name of the It test.
        FilePath      - Full path to the test file.
        DescribeName  - Name of the parent Describe block.
        Tags          - Tags explicitly set on the test.
        CombinedTags  - Union of DescribeName and Tags (unique, case-insensitive).

.PARAMETER Path
    Root path containing test files. Defaults to the 'tests' directory in the current location.

.PARAMETER ExcludePath
    [KNOWN ISSUE: Does not work.] One or more paths to exclude (e.g. test-results folders). Accepts wildcard patterns.

.PARAMETER OutputType
    Specify a desired output type for the test inventory:

    - Array: Returns an array of test inventory objects. (Default)
    - Hashtable: Groups tests by Describe and returns a hashtable keyed by Describe with values containing an object with Describe, Tags, CombinedTags and Tests (array of tests).
    - JSON: Returns the test inventory as a JSON string.
    - CSV: Returns the test inventory as a CSV string.

.EXAMPLE
    Get-TestInventory | Format-Table -AutoSize

.EXAMPLE
    $TestInventory = Get-TestInventory -Path .\ -ExcludePath .\test-results

    Get an inventory of tests in the current directory and exclude anything in the 'test-results' directory.

.EXAMPLE
    $ByDescribe = Get-TestInventory -OutputType Hashtable
    $ByDescribe['CIS']

    Get the tests under the 'CIS' Describe block.

.OUTPUTS
    An array of test inventory objects or a hashtable grouped by Describe.

.NOTES
    Requires Pester 5+.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # Path to the test files to inventory. Defaults to the project's 'tests' directory at the root.
        [Parameter(Position = 0, HelpMessage = "Path to the test files to gather inventory from.")]
        [string] $Path = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' 'tests')).Path,

        # Paths to exclude from discovery.
        [Parameter(Position = 1, HelpMessage = "One or more paths to exclude (e.g. test-results folders). Accepts wildcard patterns.")]
        [System.Obsolete("The ExcludePath parameter is known to not work as intended. Filtering will occur post-discovery.")]
        [string[]] $ExcludePath = @(),

        # Tags to exclude from discovery.
        [Parameter(HelpMessage = "One or more tags to exclude from discovery.")]
        [string[]] $ExcludeTag = @(),

        # Specify a desired output type. Defaults to an array of test inventory objects.
        [Parameter(HelpMessage = "Specify a desired output type. Defaults to an array of test inventory objects.")]
        [ValidateSet('Array', 'Hashtable','TagInventory')]
        [string] $OutputType = 'Array'
    )

    begin {
        # Update Pester if version 5 or newer is not yet installed.
        if (-not ( (Get-Module -Name Pester -ListAvailable -ErrorAction SilentlyContinue).Version -gt [version]'5.0.0' ) ) {
            try {
                Update-Module -Name Pester -AcceptLicense -Force
            }
            catch {
                throw "Failed to update Pester module: $_"
            }
        }

        # Resolve the full path of ExcludePath items and add robust variants (absolute, relative to $Path, and wildcard for directories)
        $ResolvedExcludePath = @()
        foreach ($ExcludePathItem in $ExcludePath) {
            # Convert relative paths to absolute based on the test path
            if (-not [System.IO.Path]::IsPathRooted($ExcludePathItem)) {
                $ExcludePathItem = Join-Path -Path $Path -ChildPath $ExcludePathItem
            }

            # Normalize the path
            $ExcludePathItem = [System.IO.Path]::GetFullPath($ExcludePathItem)
            $ResolvedExcludePath += $ExcludePathItem
        }

        Write-Verbose "Excluding Paths:`n`t`t$($ResolvedExcludePath -join "`n`t`t")"

        # Note: Tests that require a Microsoft Graph connection in the BeforeAll block will fail.
        if (-not (Get-MgContext -ErrorAction SilentlyContinue)) {
            Write-Warning "No Microsoft Graph connection found. Some tests may require a connection to discover successfully."
        }

        Write-Host "Checking $Path" -ForegroundColor Cyan
    }

    process {
        # Configure Pester for test discovery.
        $PesterConfig = New-PesterConfiguration
        $PesterConfig.Run.SkipRun = $true          # Discover only
        $PesterConfig.Run.PassThru = $true          # Emit discovery object
        $PesterConfig.Run.Path = $Path
        $PesterConfig.Run.ExcludePath = $ResolvedExclude
        $PesterConfig.Filter.ExcludeTag = $ExcludeTag
        $PesterConfig | Write-Verbose -Verbose
        # Discover all Pester tests.
        $Result = Invoke-Pester -Configuration $PesterConfig
        $Tests  = $Result.Tests

        Write-Verbose "Discovered $($Tests.Count) tests in $Path"
        if (-not $Tests) { return @() }

        # If ExcludePath is provided, filter out tests that match any of the excluded paths.
        if ($ResolvedExclude) {
            $Tests = $Tests | Where-Object { $ResolvedExclude -notcontains $_.ScriptBlock.File }
        }

        $AllTags = [System.Collections.Generic.List[string]]::new()

        $TestInventory = [System.Collections.Generic.List[PSCustomObject]]::new()
        # Build inventory objects.
        foreach ($TestItem in $Tests) {
            # Reset values for each TestItem
            $Tags = @()
            $Describe = ''
            [string[]]$CombinedTags = @()
            # Get values for each TestItem
            $Describe = $TestItem.Block.Name
            [string[]] $Tags = $TestItem.Tag | Where-Object { $_ } | Select-Object -Unique
            $CombinedTags += $Describe
            $CombinedTags += $Tags

            # Add the $Describe and $Tags to $AllTags
            if ($Describe) {
                $AllTags.Add($Describe)
            }
            if ($Tags.Count -gt 0) {
                $AllTags.AddRange($Tags)
            }

            $TestInventory.Add([PSCustomObject]@{
                TestName     = $TestItem.Name
                FilePath     = $TestItem.ScriptBlock.File
                DescribeName = $Describe
                Tags         = $Tags
                CombinedTags = $CombinedTags
            })
        }

        $AllTags = $AllTags | Sort-Object -Unique

        $TagInventory = [ordered]@{}
        foreach ($Tag in $AllTags) {
            $TagInventory[$Tag] = [PSCustomObject]@{
                TagName = $Tag
                Tests   = $TestInventory | Where-Object { $_.CombinedTags -contains $Tag }
            }
        }

        return $TagInventory
        <#
        # Return test inventory in the requested format.
        switch ($OutputType) {
            'Hashtable' {
                $hash = [ordered]@{}
                foreach ($Group in ($TestInventory | Group-Object DescribeName)) {
                    $AllTags = $Group.Group.Tags | ForEach-Object { $_ } | Select-Object -Unique
                    $CombinedTags = ($Group.Name + $AllTags) | Where-Object { $_ } | Sort-Object -Unique

                    $hash[$Group.Name] = [PSCustomObject]@{
                        DescribeName = $Group.Name
                        Tags         = $AllTags
                        CombinedTags = $CombinedTags
                        Tests        = $Group.Group
                    }
                }
                return $hash
            }
            'JSON' {
                return $TestInventory | ConvertTo-Json -Depth 5
            }
            'CSV' {
                return $TestInventory | Export-Csv -NoTypeInformation -Force | Out-String
            }
            'TagInventory' {
                return $AllTags
            }
            Default {
                return $TestInventory | Sort-Object DescribeName, TestName
            }
        }
        #>
    }
}
