function Get-MtTestInventory {
<#
    .SYNOPSIS
    Discover Pester test inventory and associated tags.

    .DESCRIPTION
    Uses Pester discovery to enumerate all tests under the provided path and returns a list of objects containing:

        TestName     - Name of the It test.
        FilePath     - Full path to the test file.
        Describe     - Name of the parent Describe block.
        Tags         - Tags explicitly set on the test.
        CombinedTags - Combination of Describe and Tags (unique, case-insensitive).

    .PARAMETER Path
    Root path containing the test files. Defaults to the '..\tests' directory in the current location.

    .PARAMETER ExcludePath
    One or more paths to exclude (e.g. 'test-results' directory). Accepts wildcard patterns and relative paths.

    .PARAMETER ExcludeTag
    One or more tags to exclude from discovery.

    .PARAMETER OutputType
    Specify a desired output type for the test inventory:

    - Default: Returns the test inventory as objects.
    - JSON: Returns the test inventory as a JSON string.
    - CSV: Returns the test inventory as a CSV string.
    - TagsOnly: Returns only the unique tags found in the test inventory.

    .PARAMETER ExportPath
    Path for exported CSV or JSON file. Defaults to 'TestInventory' in the current directory.

    .PARAMETER PassThru
    When specified, the test inventory object is returned to the pipeline along with exporting to file.

    .EXAMPLE
        $TestInventory = Get-MtTestInventory -Path .\ -ExcludePath .\test-results

        Get an inventory of tests in the current directory and exclude anything in the 'test-results' sub-directory.

    .EXAMPLE
        $TagInventory = Get-MtTestInventory
        $TagInventory['CIS']

        Get test test inventory and show tests with the 'CIS' tag.

    .EXAMPLE
        $Tags = Get-MtTestInventory
        $Tags -notmatch 'AzureConfig|CIS|CISA|Maester|MT.\d{4,5}|ORCA'

        Show all tags used that do not match the specified tag patterns.

    .EXAMPLE
        $TagInventory = Get-MtTestInventory
        $TagInventory.Keys -notmatch 'AzureConfig|CIS|CISA|Maester|MT.\d{4,5}|ORCA'

        foreach ($i in $TagInventory.GetEnumerator()) {
            if ($i.Key -notmatch 'AzureConfig|CIS|CISA|Maester|MT.\d{4,5}|ORCA') {
                $i
            }
        }

        Show all tags used that do not match the specified tag patterns, along with their test objects.

    .OUTPUTS
        [Ordered] (Default) - An ordered dictionary containing a list of tags and associated test inventory objects.
        [String] - JSON string of test inventory (when OutputType is 'JSON').
        [String] - CSV string of test inventory (when OutputType is 'CSV').
        [String[]] - Array of unique tags (when OutputType is 'TagsOnly').

    .NOTES
    Requires Pester 5+.

    .LINK
    https://maester.dev/docs/commands/Get-MtTestInventory
#>
    [CmdletBinding()]
    param(
        # Path to the test files to inventory. Defaults to the project's 'tests' directory at the root.
        [Parameter(HelpMessage = 'Path to the test files to gather inventory from.')]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [string] $Path = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot '..\..' 'tests')).Path,

        # Paths to exclude from discovery.
        [Parameter(HelpMessage = 'One or more paths to exclude (e.g. test-results folders). Accepts wildcard patterns.')]
        [string[]] $ExcludePath,

        # Tags to exclude from discovery.
        [Parameter(HelpMessage = 'One or more tags to exclude from discovery.')]
        [string[]] $ExcludeTag,

        # Specify a desired output type. Defaults to an array of test inventory objects.
        [Parameter(ParameterSetName = 'Output', HelpMessage = 'Specify a desired output type. Defaults to an array of test inventory objects.')]
        [ValidateSet('Default', 'JSON', 'CSV', 'TagsOnly')]
        [string] $OutputType = 'Default',

        # Path for exported CSV or JSON file.
        [Parameter(ParameterSetName = 'Output', HelpMessage = 'Path for exported CSV or JSON file.')]
        [string] $ExportPath = (Join-Path -Path $PWD -ChildPath 'TestInventory'),

        # Support PassThru: return the test inventory object along with exporting to file.
        [Parameter()]
        [switch] $PassThru
    )

    begin {
        # Resolve the full path of ExcludePath items and add robust variants (absolute, relative to $PWD, and wildcard for directories).
        $ExcludePathResolved = @()
        foreach ($ExcludePathItem in $ExcludePath) {
            # Convert relative paths to absolute based on the current working directory.
            if (-not [System.IO.Path]::IsPathRooted($ExcludePathItem)) {
                $ExcludePathItem = Join-Path -Path $PWD.Path -ChildPath $ExcludePathItem
            }
            # Normalize the path
            $ExcludePathItem = [System.IO.Path]::GetFullPath($ExcludePathItem)
            $ExcludePathResolved += $ExcludePathItem
        }
        Write-Verbose "Excluding Paths:`n`t`t$($ExcludePathResolved -join "`n`t`t")"

        if ($ExportPath) {
            # Check for a proper filename and extension based on the OutputType parameter.
            if (-not ([System.IO.Path]::GetFileName($ExportPath))) {
                $ExportPath = $ExportPath.TrimEnd('\') + '\TestInventory'
            }
            switch ($OutputType) {
                'JSON' {
                    if (-not $ExportPath.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)) {
                        $ExportPath += '.json'
                    }
                }
                'CSV' {
                    if (-not $ExportPath.EndsWith('.csv', [StringComparison]::OrdinalIgnoreCase)) {
                        $ExportPath += '.csv'
                    }
                }
            }
        }
    } # End of begin block

    process {
        #region PesterDiscovery
        # Configure Pester for test discovery.
        $PesterConfig = New-PesterConfiguration
        $PesterConfig.Run.SkipRun = $true          # Discover only
        $PesterConfig.Run.PassThru = $true          # Emit discovery object
        $PesterConfig.Run.Path = @($Path)
        if ($ExcludePathResolved) {
            $PesterConfig.Run.ExcludePath = $ExcludePathResolved
        }
        if ($ExcludeTag) {
            $PesterConfig.Filter.ExcludeTag = $ExcludeTag
        }
        # Discover all Pester tests.
        try {
            $Result = Invoke-Pester -Configuration $PesterConfig
        } catch {
            Write-Error "Failed to run Pester discovery: $($_.Exception.Message)"
            return
        }

        if ($null -eq $Result) {
            Write-Warning "No tests found in path: $Path"
            return
        }
        $Tests = $Result.Tests
        Write-Verbose "Discovered $($Tests.Count) tests in $Path"
        #endregion PesterDiscovery

        #region FilterResults
        # This is required because Run.ExcludePath does not work with directories in Pester 5.
        if ($ExcludePathResolved) {
            Write-Verbose "Excluding tests in paths:`n`t`t$($ExcludePathResolved -join "`n`t`t")"
            $Tests = $Tests | Where-Object {
                # Exclude tests whose file is in any excluded directory or matches any excluded file
                $testFile = [System.IO.Path]::GetFullPath($_.ScriptBlock.File)
                $exclude = $false
                foreach ($excludePath in $ExcludePathResolved) {
                    $fullExcludePath = [System.IO.Path]::GetFullPath($excludePath)
                    if ($testFile.StartsWith($fullExcludePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                        $exclude = $true
                        break
                    }
                    # File exclusion: check for exact match
                    if ($testFile -eq $fullExcludePath) {
                        $exclude = $true
                        break
                    } # end if TestFile
                } # end foreach ExcludePath
                -not $exclude
            } # end Where
        } # end if

        # This is included as a fallback in case the Filter.ExcludeTag Pester configuration does not work.
        if ($ExcludeTag) {
            Write-Verbose "Excluding tests with tags: $($ExcludeTag -join ', ')"
            $Tests = $Tests | Where-Object {
                -not ($_.Tag | Where-Object { $ExcludeTag -contains $_ })
            }
        }
        #endregion FilterResults

        # Initialize the list to contain all discovered tags.
        $AllTags = [System.Collections.Generic.List[string]]::new()

        # Initialize the list to contain all test inventory objects.
        $TestInventory = [System.Collections.Generic.List[PSCustomObject]]::new()
        # Build inventory objects.
        foreach ($TestItem in $Tests) {
            # Reset values for each TestItem
            $Tags = @()
            $Describe = ''
            [string[]]$CombinedTags = @()
            # Get values for each TestItem
            $Describe = $TestItem.Block.Name

            # Collect tags from both the individual test and its parent Describe block
            [string[]] $TestTags = $TestItem.Tag | Where-Object { $_ } | Select-Object -Unique
            [string[]] $DescribeTags = $TestItem.Block.Tag | Where-Object { $_ } | Select-Object -Unique
            [string[]] $Tags = ($TestTags + $DescribeTags) | Select-Object -Unique

            $CombinedTags += $Describe
            $CombinedTags += $Tags

            # Add $Describe and $Tags to the $AllTags list.
            if ($Describe) {
                $AllTags.Add($Describe)
            }
            if ($Tags.Count -gt 0) {
                foreach ($tag in $Tags) {
                    $AllTags.Add($tag)
                }
            }

            # Add the test object to the test inventory list.
            $TestInventory.Add([PSCustomObject]@{
                    TestName     = $TestItem.Name
                    FilePath     = $TestItem.ScriptBlock.File
                    Describe     = $Describe
                    Tags         = $Tags
                    CombinedTags = $CombinedTags
                })
        }

        # Ensure AllTags only contains unique and sorted objects.
        $AllTags = $AllTags | Sort-Object -Property $_ -Unique

        # Create the tag inventory as an ordered dictionary with the tag names as keys and tests as values.
        # This will allow for quick lookups of tests by any of their tags.
        $TagTests = [ordered]@{}
        foreach ($Tag in $AllTags) {
            $TagTests[$Tag] = $TestInventory | Where-Object { $_.CombinedTags -contains $Tag }
        }

        # Return test inventory to the pipeline in the requested format.
        switch ($OutputType) {
            'JSON' {
                try {
                    $TestInventory | ConvertTo-Json -Depth 5 | Out-File -FilePath $ExportPath -Encoding utf8NoBOM
                    Write-Verbose "Test inventory exported to: $ExportPath"
                } catch {
                    Write-Error "Failed to export JSON to '$ExportPath': $($_.Exception.Message)"
                }
                if ($PassThru) {
                    $TagTests
                }
            }
            'CSV' {
                try {
                    $TestInventory | Export-Csv -NoTypeInformation -Path $ExportPath -Encoding utf8NoBOM
                    Write-Verbose "Test inventory exported to: $ExportPath"
                } catch {
                    Write-Error "Failed to export CSV to '$ExportPath': $($_.Exception.Message)"
                }
                if ($PassThru) {
                    $TagTests
                }
            }
            'TagsOnly' {
                $AllTags
            }
            default {
                $TagTests
            }
        } # End of switch block
    } # End of process block
}
