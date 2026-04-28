function Import-MtMaesterResult {
    <#
     .Synopsis
      Imports Maester test result JSON files from disk into PowerShell objects.

     .Description
        Loads one or more Maester test result JSON files and returns them as an array
        of single-tenant MaesterResults objects. This is the standard way to load
        previously saved results for use with Merge-MtMaesterResult, Compare-MtTestResult,
        or any future command that operates on result objects.

        If a loaded JSON file contains a multi-tenant merged format (i.e. a "Tenants"
        array from a prior Merge-MtMaesterResult call), each tenant is automatically
        expanded into a separate result object.

        Accepts file paths, glob patterns, or directory paths. When a directory is
        provided, it auto-discovers TestResults-*.json files inside it.

     .Parameter Path
        One or more paths to JSON result files, glob patterns, or directories.
        - File path:  ./production.json
        - Glob:       ./results/*.json
        - Directory:  ./results/  (discovers TestResults-*.json inside)

     .Example
        # Load a single result file
        Import-MtMaesterResult -Path ./production.json

     .Example
        # Load all JSON files matching a glob
        Import-MtMaesterResult -Path ./results/*.json

     .Example
        # Load from a directory (auto-discovers TestResults-*.json)
        Import-MtMaesterResult -Path ./test-results/

     .Example
        # Pipe into Merge for a multi-tenant report
        Import-MtMaesterResult -Path *.json | Merge-MtMaesterResult | Get-MtHtmlReport | Out-File report.html

     .LINK
        https://maester.dev/docs/commands/Import-MtMaesterResult
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string[]] $Path
    )

    begin {
        # Required properties that every single-tenant result must have.
        # This is the same validation used in Compare-MtTestResult.
        $requiredProperties = @('Tests', 'TenantId', 'ExecutedAt')

        $allResults = [System.Collections.Generic.List[psobject]]::new()
    }

    process {
        foreach ($inputPath in $Path) {
            # Resolve the path - handles globs, relative paths, etc.
            $resolvedPaths = @()
            try {
                $resolvedPaths = @(Resolve-Path -Path $inputPath -ErrorAction Stop | Select-Object -ExpandProperty Path)
            } catch {
                Write-Error "Path not found: $inputPath"
                continue
            }

            foreach ($resolved in $resolvedPaths) {
                if (Test-Path -Path $resolved -PathType Container) {
                    # Directory: auto-discover TestResults-*.json files
                    $jsonFiles = @(Get-ChildItem -Path $resolved -Filter 'TestResults-*.json' -File)
                    if ($jsonFiles.Count -eq 0) {
                        # Fall back to any .json file in the directory
                        $jsonFiles = @(Get-ChildItem -Path $resolved -Filter '*.json' -File)
                    }
                    if ($jsonFiles.Count -eq 0) {
                        Write-Warning "No JSON result files found in directory: $resolved"
                        continue
                    }
                    Write-Verbose "Found $($jsonFiles.Count) JSON file(s) in directory: $resolved"
                    foreach ($file in $jsonFiles) {
                        Import-SingleResultFile -FilePath $file.FullName -RequiredProperties $requiredProperties -ResultList $allResults
                    }
                } elseif (Test-Path -Path $resolved -PathType Leaf) {
                    # Single file
                    Import-SingleResultFile -FilePath $resolved -RequiredProperties $requiredProperties -ResultList $allResults
                } else {
                    Write-Error "Path is neither a file nor a directory: $resolved"
                }
            }
        }
    }

    end {
        if ($allResults.Count -eq 0) {
            Write-Warning "No valid Maester result files were loaded."
        } else {
            Write-Verbose "Loaded $($allResults.Count) Maester result(s) in total."
        }
        return , $allResults.ToArray()
    }
}

function Import-SingleResultFile {
    <#
    .Synopsis
        Helper: loads a single JSON file and adds valid results to the list.
        Handles both single-tenant and multi-tenant (merged) formats.
    #>
    [CmdletBinding()]
    param(
        [string] $FilePath,
        [string[]] $RequiredProperties,
        [System.Collections.Generic.List[psobject]] $ResultList
    )

    Write-Verbose "Loading: $FilePath"
    try {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        $data = $content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning "Failed to read or parse JSON from '$FilePath': $_"
        return
    }

    # Check if this is a multi-tenant merged format (has Tenants[] array)
    if ($data.PSObject.Properties.Name -contains 'Tenants' -and $null -ne $data.Tenants) {
        Write-Verbose "  Detected multi-tenant merged format with $($data.Tenants.Count) tenant(s) in: $FilePath"
        foreach ($tenant in $data.Tenants) {
            if (Test-MaesterResultValid -Result $tenant -RequiredProperties $RequiredProperties -SourceFile $FilePath) {
                $ResultList.Add($tenant)
            }
        }
    } else {
        # Single-tenant format
        if (Test-MaesterResultValid -Result $data -RequiredProperties $RequiredProperties -SourceFile $FilePath) {
            $ResultList.Add($data)
        }
    }
}

function Test-MaesterResultValid {
    <#
    .Synopsis
        Helper: validates that a result object has the required properties.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [psobject] $Result,
        [string[]] $RequiredProperties,
        [string] $SourceFile
    )

    foreach ($prop in $RequiredProperties) {
        if (-not ($Result.PSObject.Properties.Name -contains $prop)) {
            Write-Warning "Result from '$SourceFile' is missing required property '$prop'. Skipping."
            return $false
        }
    }
    return $true
}
