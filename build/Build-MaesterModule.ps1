<#
.SYNOPSIS
    Builds the Maester PowerShell module into a consolidated, publishable artifact.

.DESCRIPTION
    Consolidates all source files from powershell/internal/ and powershell/public/ into
    a single Maester.psm1, consolidates ORCA class definitions into OrcaClasses.ps1,
    auto-generates the FunctionsToExport list via AST parsing, and copies static assets
    and tests into the output directory.

    The source tree is never modified. All output goes to the OutputRoot directory.

.PARAMETER SourceRoot
    Path to the PowerShell module source directory. Defaults to ../powershell relative
    to this script.

.PARAMETER TestsRoot
    Path to the test suites directory. Defaults to ../tests relative to this script.

.PARAMETER OutputRoot
    Path to the output directory for the built module. Defaults to ../module relative
    to this script. This directory is cleaned and recreated on every run.

.PARAMETER Format
    When specified, normalizes source file indentation to 4 spaces using
    Invoke-Formatter (PSScriptAnalyzer) during consolidation. Requires the
    PSScriptAnalyzer module to be installed. Without this switch, source
    content is concatenated as-is.

.PARAMETER Profile
    When specified, measures and reports Import-Module time and exported function count
    for the built module.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $SourceRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../powershell").Path,

    [Parameter()]
    [string] $TestsRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../tests").Path,

    [Parameter()]
    [string] $OutputRoot = "$PSScriptRoot/../module",

    [Parameter()]
    [switch] $Format,

    [Parameter()]
    [switch] $Profile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ──────────────────────────────────────────────────────────────────────────────
# Phase A — Clean and recreate the output directory
# ──────────────────────────────────────────────────────────────────────────────

Write-Host '── Phase A: Preparing output directory' -ForegroundColor Cyan

# Safety guard: reject OutputRoot paths that could cause catastrophic deletion.
$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$ResolvedOutput = [System.IO.Path]::GetFullPath($OutputRoot).TrimEnd('\', '/')
$DriveRoot = [System.IO.Path]::GetPathRoot($ResolvedOutput).TrimEnd('\', '/')
if ($ResolvedOutput -ieq $DriveRoot) {
    throw "Refusing to use OutputRoot '$OutputRoot' because it resolves to a filesystem root: '$ResolvedOutput'."
}
if ($ResolvedOutput -ieq $RepoRoot.TrimEnd('\', '/')) {
    throw "Refusing to use OutputRoot '$OutputRoot' because it resolves to the repository root: '$RepoRoot'."
}
$RepoPath = $RepoRoot.TrimEnd('\', '/')
if (-not $ResolvedOutput.StartsWith($RepoPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use OutputRoot '$OutputRoot' because it is outside the repository root '$RepoRoot'."
}

if (Test-Path -LiteralPath $OutputRoot) {
    Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}
$null = New-Item -Path $OutputRoot -ItemType Directory -Force
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path

Write-Host "   Output: $OutputRoot"

# ──────────────────────────────────────────────────────────────────────────────
# Phase B — AST parsing: collect FunctionsToExport from public source files
# ──────────────────────────────────────────────────────────────────────────────

Write-Host '── Phase B: Parsing public functions (AST)' -ForegroundColor Cyan

$PublicSourceFiles = Get-ChildItem -Path "$SourceRoot/public" -Filter '*.ps1' -Recurse |
    Where-Object { $_.Name -notlike '*.Tests.ps1' } |
        Sort-Object -Property FullName

$ApprovedVerbs = (Get-Verb).Verb

$ExportFunctionList = [System.Collections.Generic.List[string]]::new()

foreach ($File in $PublicSourceFiles) {
    $Tokens = $null
    $ParseErrors = $null
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $File.FullName, [ref]$Tokens, [ref]$ParseErrors
    )

    if ($ParseErrors.Count -gt 0) {
        Write-Warning "Parse errors in '$($File.Name)': $($ParseErrors[0].Message)"
    }

    # Find top-level function definitions only (not nested inside other functions
    # and not nested anywhere inside a type definition). Walk the full parent chain — any
    # FunctionDefinitionAst or TypeDefinitionAst ancestor means this function definition is nested,
    # regardless of intermediate block types.
    $TopLevelFunctions = $Ast.FindAll({
            param ($Node)
            if ($Node -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
                return $false
            }
            $Parent = $Node.Parent
            while ($Parent) {
                if ($Parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
                    return $false
                }
                if ($Parent -is [System.Management.Automation.Language.TypeDefinitionAst]) {
                    return $false
                }
                $Parent = $Parent.Parent
            }
            return $true
        }, $true)

    if ($TopLevelFunctions.Count -eq 0) {
        Write-Warning "No top-level function found in '$($File.Name)'"
        continue
    }

    if ($TopLevelFunctions.Count -gt 1) {
        $Names = ($TopLevelFunctions | ForEach-Object { $_.Name }) -join ', '
        Write-Warning "Multiple top-level functions in '$($File.Name)': $Names"
    }

    # Only export the function whose name matches the filename. Additional
    # top-level functions (helpers co-located in the same file) are logged
    # and skipped to avoid unintentionally expanding the public API surface.
    $MatchingFunction = $TopLevelFunctions | Where-Object { $_.Name -eq $File.BaseName } | Select-Object -First 1
    if (-not $MatchingFunction) {
        $DiscoveredNames = ($TopLevelFunctions | ForEach-Object { $_.Name }) -join ', '
        Write-Warning "No top-level function matching filename '$($File.Name)' was found. Discovered: $DiscoveredNames"
        continue
    }

    $AdditionalTopLevelFunctions = $TopLevelFunctions | Where-Object { $_.Name -ne $File.BaseName }
    foreach ($Extra in $AdditionalTopLevelFunctions) {
        Write-Warning "Skipping additional top-level function '$($Extra.Name)' in '$($File.Name)' — only '$($File.BaseName)' is exported"
    }

    # Only export functions that follow the Verb-Noun naming convention.
    if ($MatchingFunction.Name -notmatch '-') {
        Write-Warning "Skipping '$($MatchingFunction.Name)' in '$($File.Name)' — not a Verb-Noun function"
        continue
    }

    # Validate approved verb
    $Verb = ($MatchingFunction.Name -split '-', 2)[0]
    if ($Verb -and $Verb -notin $ApprovedVerbs) {
        Write-Warning "Function '$($MatchingFunction.Name)' uses unapproved verb '$Verb'"
    }

    $ExportFunctionList.Add($MatchingFunction.Name)
}

$ExportFunctionList.Sort([System.StringComparer]::OrdinalIgnoreCase)

# Deduplicate — some helper functions (e.g., SPFRecord) are defined in multiple files.
$SeenFunctions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$DuplicateNames = [System.Collections.Generic.List[string]]::new()
foreach ($Name in $ExportFunctionList) {
    if (-not $SeenFunctions.Add($Name)) {
        $DuplicateNames.Add($Name)
    }
}
if ($DuplicateNames.Count -gt 0) {
    $ExportFunctionList = [System.Collections.Generic.List[string]]::new($SeenFunctions)
    $ExportFunctionList.Sort([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Dupe in $DuplicateNames) {
        Write-Warning "Deduplicated function: '$Dupe'"
    }
    Write-Warning "Removed $($DuplicateNames.Count) duplicate function name(s)"
}

Write-Host "   Found $($ExportFunctionList.Count) public functions"

# ──────────────────────────────────────────────────────────────────────────────
# Phase C — Consolidate internal + public .ps1 files into Maester.psm1
# ──────────────────────────────────────────────────────────────────────────────

Write-Host '── Phase C: Consolidating Maester.psm1' -ForegroundColor Cyan

$InternalFiles = Get-ChildItem -Path "$SourceRoot/internal" -Filter '*.ps1' -Recurse |
    Where-Object {
        $_.Name -notlike '*.Tests.ps1' -and
        $_.Name -notlike 'check-ORCA*.ps1'
    } |
        Sort-Object -Property FullName

$PublicFiles = Get-ChildItem -Path "$SourceRoot/public" -Filter '*.ps1' -Recurse |
    Where-Object { $_.Name -notlike '*.Tests.ps1' } |
        Sort-Object -Property FullName

Write-Host "   Internal files: $($InternalFiles.Count)"
Write-Host "   Public files:   $($PublicFiles.Count)"

# Helper: compute directory depth of a file relative to $SourceRoot.
# e.g. powershell/internal/foo.ps1 → depth 1, powershell/public/core/bar.ps1 → depth 2
function Get-RelativeDepth {
    param (
        [string] $FilePath,
        [string] $BasePath
    )
    $RelativePath = $FilePath.Substring($BasePath.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $DirectoryPart = [System.IO.Path]::GetDirectoryName($RelativePath)
    if ([string]::IsNullOrEmpty($DirectoryPart)) {
        return 0
    }
    return ($DirectoryPart.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)).Count
}

# Helper: adjust $PSScriptRoot-relative paths in consolidated file content.
# After consolidation, $PSScriptRoot resolves to the output directory root instead of
# each file's original subdirectory. This function strips the appropriate number of
# parent-directory traversals (../) based on the file's original depth.
function Resolve-ConsolidatedPaths {
    param (
        [string] $Content,
        [int]    $Depth,
        [string] $FileName
    )

    if ($Depth -lt 1) {
        return $Content
    }

    # Build the parent-navigation patterns for forward and back slashes.
    # Depth 1: '../'  or  '..\'
    # Depth 2: '../../'  or  '..\..\'
    $ForwardPattern = ('../' * $Depth)
    $BackslashPattern = ('..\' * $Depth)

    # Pattern A: inline string interpolation — $PSScriptRoot/../... or $PSScriptRoot\..\...
    $Content = $Content.Replace("`$PSScriptRoot/$ForwardPattern", '$PSScriptRoot/')
    $Content = $Content.Replace("`$PSScriptRoot\$BackslashPattern", '$PSScriptRoot\')

    # Pattern B: Join-Path with separate -ChildPath string arguments — '../...' or '..\..'
    # Process line-by-line to only adjust lines that reference $PSScriptRoot.
    $Lines = $Content -split "`n"
    $AdjustedLines = [System.Collections.Generic.List[string]]::new($Lines.Count)
    foreach ($Line in $Lines) {
        if ($Line -match '\$PSScriptRoot') {
            $Line = $Line.Replace("'$ForwardPattern", "'")
            $Line = $Line.Replace("'$BackslashPattern", "'")
            $Line = $Line.Replace("""$ForwardPattern", '"')
            $Line = $Line.Replace("""$BackslashPattern", '"')
        }
        $AdjustedLines.Add($Line)
    }
    $Content = $AdjustedLines -join "`n"

    # Safety check: warn about any remaining parent-directory navigation after $PSScriptRoot
    if ($Content -match '\$PSScriptRoot[/\\]\.\.') {
        Write-Warning "Remaining `$PSScriptRoot/.. reference in consolidated content from '$FileName' — manual review recommended"
    }

    return $Content
}

# Helper: strip file-level preamble lines that are only valid at the top of an
# individual .ps1 script file. When concatenated into a single PSM1, these bare
# attributes and param() become syntax errors. This function only removes leading
# preamble lines (before the first function/class definition), leaving identical
# attributes inside function bodies untouched.
function Remove-FileLevelPreamble {
    param (
        [string] $Content,
        [string] $FileName = ''
    )

    $SuppressPattern = '^\s*\[Diagnostics\.CodeAnalysis\.SuppressMessageAttribute\('
    $ParamPattern = '^\s*param\s*\(\s*\)\s*$'
    $UsingModulePattern = '^\s*using\s+module\s+'
    $GeneratedPattern = '^\s*#\s*Generated by'

    $Lines = $Content -split "`n"
    $Result = [System.Collections.Generic.List[string]]::new($Lines.Count)
    $StrippedItems = [System.Collections.Generic.List[string]]::new()
    $InPreamble = $true

    foreach ($Line in $Lines) {
        if ($InPreamble) {
            # While in the preamble region, skip lines matching preamble patterns.
            # Stop the preamble at the first line that is actual code (function,
            # class, or any non-blank, non-comment, non-preamble line).
            $Trimmed = $Line.Trim()

            if ($Trimmed -eq '' -or $Trimmed.StartsWith('#')) {
                # Blank lines and regular comments — keep in preamble region.
                # But skip "# Generated by" comments.
                if ($Trimmed -match $GeneratedPattern) {
                    $StrippedItems.Add('Generated-by comment')
                    continue
                }
                $Result.Add($Line)
                continue
            }

            if ($Trimmed -match $SuppressPattern) {
                $StrippedItems.Add('SuppressMessageAttribute')
                continue
            }
            if ($Trimmed -match $ParamPattern) {
                $StrippedItems.Add('param()')
                continue
            }
            if ($Trimmed -match $UsingModulePattern) {
                $StrippedItems.Add('using module')
                continue
            }

            # This line is actual code — exit preamble mode and keep it.
            $InPreamble = $false
            $Result.Add($Line)
        } else {
            $Result.Add($Line)
        }
    }

    if ($StrippedItems.Count -gt 0 -and $FileName) {
        Write-Host "   Stripped preamble from '$FileName': $($StrippedItems -join ', ')"
    }

    return ($Result -join "`n")
}

# Helper: normalize indentation to 4 spaces using Invoke-Formatter.
# Only called when the -Format switch is specified. Requires PSScriptAnalyzer.
function Format-SourceContent {
    param (
        [string] $Content,
        [string] $FileName = ''
    )

    $Settings = @{
        IncludeRules = @('PSUseConsistentIndentation')
        Rules        = @{
            PSUseConsistentIndentation = @{
                Enable          = $true
                IndentationSize = 4
                Kind            = 'space'
            }
        }
    }

    try {
        $Formatted = Invoke-Formatter -ScriptDefinition $Content -Settings $Settings
        return $Formatted
    } catch {
        Write-Warning "Invoke-Formatter failed for '$FileName': $($_.Exception.Message)"
        return $Content
    }
}

# Validate PSScriptAnalyzer availability when -Format is requested.
if ($Format) {
    if (-not (Get-Command -Name Invoke-Formatter -ErrorAction SilentlyContinue)) {
        Write-Warning 'PSScriptAnalyzer module is not installed. The -Format switch requires it. Continuing without formatting.'
        $Format = $false
    } else {
        Write-Host '   Formatting enabled (Invoke-Formatter)'
    }
}

# Build the consolidated PSM1 content.
$Builder = [System.Text.StringBuilder]::new()

# Preamble: module header, #Requires, and session variable initialization.
# Extracted from the source Maester.psm1 — the dot-sourcing loops are replaced by
# the inline consolidated content below.
$null = $Builder.AppendLine(@'
<#
.DISCLAIMER
    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
    ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
    THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
    PARTICULAR PURPOSE.

    Copyright (c) Microsoft Corporation. All rights reserved.
#>

## Initialize Module Configuration
#Requires -Modules Pester, Microsoft.Graph.Authentication

## Initialize Module Variables
## Update Clear-ModuleVariable function in internal/Clear-ModuleVariable.ps1 if you add new variables here
$__MtSession = @{
    GraphCache = @{}
    GraphBaseUri = $null
    TestResultDetail = @{}
    Connections = @()
    DnsCache = @()
    ExoCache = @{}
    OrcaCache = @{}
    AIAgentInfo = $null
    DataverseApiBase = $null       # Resolved Dataverse OData API base URL (e.g. https://org123.api.crm.dynamics.com/api/data/v9.2)
    DataverseResourceUrl = $null   # Dataverse resource URL for token acquisition (e.g. https://org123.crm.dynamics.com)
    DataverseEnvironmentId = $null # Environment identifier for display (e.g. org123.crm.dynamics.com)
}
New-Variable -Name __MtSession -Value $__MtSession -Scope Script -Force
'@)

$null = $Builder.AppendLine()
$null = $Builder.AppendLine('#region Internal Functions')
$null = $Builder.AppendLine()

foreach ($File in $InternalFiles) {
    $FileContent = Get-Content -Path $File.FullName -Raw
    $FileContent = Remove-FileLevelPreamble -Content $FileContent -FileName $File.Name
    $Depth = Get-RelativeDepth -FilePath $File.FullName -BasePath $SourceRoot
    $FileContent = Resolve-ConsolidatedPaths -Content $FileContent -Depth $Depth -FileName $File.Name
    if ($Format) {
        $FileContent = Format-SourceContent -Content $FileContent -FileName $File.Name
    }

    $null = $Builder.AppendLine("# ── $($File.Name) ──")
    $null = $Builder.AppendLine($FileContent.TrimEnd())
    $null = $Builder.AppendLine()
}

$null = $Builder.AppendLine('#endregion Internal Functions')
$null = $Builder.AppendLine()
$null = $Builder.AppendLine('#region Public Functions')
$null = $Builder.AppendLine()

foreach ($File in $PublicFiles) {
    $FileContent = Get-Content -Path $File.FullName -Raw
    $FileContent = Remove-FileLevelPreamble -Content $FileContent -FileName $File.Name
    $Depth = Get-RelativeDepth -FilePath $File.FullName -BasePath $SourceRoot
    $FileContent = Resolve-ConsolidatedPaths -Content $FileContent -Depth $Depth -FileName $File.Name
    if ($Format) {
        $FileContent = Format-SourceContent -Content $FileContent -FileName $File.Name
    }

    $null = $Builder.AppendLine("# ── $($File.Name) ──")
    $null = $Builder.AppendLine($FileContent.TrimEnd())
    $null = $Builder.AppendLine()
}

$null = $Builder.AppendLine('#endregion Public Functions')
$null = $Builder.AppendLine()

# Read aliases from the source manifest for the Export-ModuleMember statement.
$SourceManifest = Import-PowerShellDataFile -Path "$SourceRoot/Maester.psd1"
$AliasExportList = $SourceManifest['AliasesToExport']

$FunctionExportString = ($ExportFunctionList | ForEach-Object { "'$_'" }) -join ",`n    "
$AliasExportString = ($AliasExportList | ForEach-Object { "'$_'" }) -join ', '

$null = $Builder.AppendLine('Export-ModuleMember -Function @(')
$null = $Builder.AppendLine("    $FunctionExportString")
$null = $Builder.AppendLine(") -Alias @($AliasExportString)")
$null = $Builder.AppendLine()

# Safely import module manifest (mirrors source Maester.psm1 behavior).
$null = $Builder.AppendLine(@'
# Safely import module manifest
try {
    $ModuleInfo = Import-PowerShellDataFile -Path "$PSScriptRoot/Maester.psd1" -ErrorAction Stop
} catch {
    Write-Warning "Failed to load module manifest: $($_.Exception.Message)"
    $ModuleInfo = $null
}
'@)

$OutputPsm1 = Join-Path $OutputRoot 'Maester.psm1'
Set-Content -Path $OutputPsm1 -Value $Builder.ToString() -Encoding utf8BOM -NoNewline
Write-Host '   Written: Maester.psm1'

# ──────────────────────────────────────────────────────────────────────────────
# Phase D — Consolidate ORCA class files into OrcaClasses.ps1
# ──────────────────────────────────────────────────────────────────────────────

Write-Host '── Phase D: Consolidating ORCA classes' -ForegroundColor Cyan

$OrcaBuilder = [System.Text.StringBuilder]::new()

# Base classes and enums from orcaClass.psm1 — must come first (defines all base
# types before any derived check classes).
$OrcaClassPath = Join-Path $SourceRoot 'internal/orca/orcaClass.psm1'
$OrcaBaseContent = Get-Content -Path $OrcaClassPath -Raw

$null = $OrcaBuilder.AppendLine('# Consolidated ORCA class definitions')
$null = $OrcaBuilder.AppendLine('# Generated by Build-MaesterModule.ps1 — do not edit manually.')
$null = $OrcaBuilder.AppendLine()
$null = $OrcaBuilder.AppendLine('# ── Base Classes and Enums (orcaClass.psm1) ──')
$null = $OrcaBuilder.AppendLine($OrcaBaseContent.TrimEnd())
$null = $OrcaBuilder.AppendLine()

# Derived check classes — each check-ORCA*.ps1 file defines a class that inherits
# from ORCACheck. The `using module` directive is stripped because the base classes
# are now defined inline above.
$OrcaCheckFiles = Get-ChildItem -Path "$SourceRoot/internal/orca" -Filter 'check-ORCA*.ps1' |
    Sort-Object -Property Name

$UsingModulePattern = '^\s*using\s+module\s+["'']\.[\\/]orcaClass\.psm1["'']\s*$'

foreach ($File in $OrcaCheckFiles) {
    $FileContent = Get-Content -Path $File.FullName -Raw

    # Strip file-level preamble (SuppressMessageAttribute, param(), Generated-by,
    # using module) using the same preamble-aware helper as Phase C.
    $FileContent = Remove-FileLevelPreamble -Content $FileContent -FileName $File.Name
    if ($Format) {
        $FileContent = Format-SourceContent -Content $FileContent -FileName $File.Name
    }

    # Also strip 'using module' references to the base class file that appear outside
    # the preamble, since the base classes are now defined inline above.
    if ($FileContent -match $UsingModulePattern) {
        $FileContent = ($FileContent -split "`n" |
                Where-Object { $_ -notmatch $UsingModulePattern }) -join "`n"
    }

    $null = $OrcaBuilder.AppendLine("# ── $($File.Name) ──")
    $null = $OrcaBuilder.AppendLine($FileContent.TrimEnd())
    $null = $OrcaBuilder.AppendLine()
}

$OutputOrcaClasses = Join-Path $OutputRoot 'OrcaClasses.ps1'
Set-Content -Path $OutputOrcaClasses -Value $OrcaBuilder.ToString() -Encoding utf8BOM -NoNewline
Write-Host "   Written: OrcaClasses.ps1 ($($OrcaCheckFiles.Count) check classes)"

# ──────────────────────────────────────────────────────────────────────────────
# Phase E — Copy static assets (must run before manifest update so that
#           FormatsToProcess references can be validated)
# ──────────────────────────────────────────────────────────────────────────────

Write-Host '── Phase E: Copying static assets' -ForegroundColor Cyan

# Assets directory
$AssetsSource = Join-Path $SourceRoot 'assets'
$AssetsOutput = Join-Path $OutputRoot 'assets'
Copy-Item -Path $AssetsSource -Destination $AssetsOutput -Recurse -Force
Write-Host '   Copied: assets/'

# Format file
$FormatFile = Join-Path $SourceRoot 'Maester.Format.ps1xml'
if (Test-Path -LiteralPath $FormatFile) {
    Copy-Item -Path $FormatFile -Destination $OutputRoot -Force
    Write-Host '   Copied: Maester.Format.ps1xml'
}

# README
<# To Do: Consider creating a simplified README that is intended specifically to be shipped with the module. Otherwise, do not include.
$ReadmeFile = Join-Path $SourceRoot 'README.md'
if (Test-Path -LiteralPath $ReadmeFile) {
    Copy-Item -Path $ReadmeFile -Destination $OutputRoot -Force
    Write-Host '   Copied: README.md'
}
#>

# ──────────────────────────────────────────────────────────────────────────────
# Phase F — Copy and update module manifest
# ──────────────────────────────────────────────────────────────────────────────

Write-Host '── Phase F: Updating module manifest' -ForegroundColor Cyan

$OutputManifest = Join-Path $OutputRoot 'Maester.psd1'
Copy-Item -Path "$SourceRoot/Maester.psd1" -Destination $OutputManifest -Force

# Update FunctionsToExport and ScriptsToProcess in the output manifest.
Update-ModuleManifest -Path $OutputManifest `
    -FunctionsToExport $ExportFunctionList.ToArray() `
    -ScriptsToProcess @('OrcaClasses.ps1')

Write-Host "   FunctionsToExport: $($ExportFunctionList.Count) functions"
Write-Host '   ScriptsToProcess:  OrcaClasses.ps1'

# ──────────────────────────────────────────────────────────────────────────────
# Phase G — Copy tests as-is (PR 3 will replace with per-suite consolidation)
# ──────────────────────────────────────────────────────────────────────────────

Write-Host '── Phase G: Copying test suites' -ForegroundColor Cyan

$TestsOutput = Join-Path $OutputRoot 'maester-tests'
Copy-Item -Path $TestsRoot -Destination $TestsOutput -Recurse -Force
Write-Host '   Copied: tests/ → maester-tests/'

# ──────────────────────────────────────────────────────────────────────────────
# Phase H — Build profiling (optional)
# ──────────────────────────────────────────────────────────────────────────────

if ($Profile) {
    Write-Host '── Phase H: Profiling module import' -ForegroundColor Cyan

    $OutputManifestPath = Join-Path $OutputRoot 'Maester.psd1'
    $ImportTime = Measure-Command {
        Import-Module $OutputManifestPath -Force -ErrorAction Stop
    }
    $CommandCount = (Get-Command -Module Maester).Count

    Write-Host "   Import time:     $([math]::Round($ImportTime.TotalSeconds, 3))s"
    Write-Host "   Exported commands: $CommandCount"

    Remove-Module Maester -Force -ErrorAction SilentlyContinue
}

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '── Build complete' -ForegroundColor Green
Write-Host "   Output directory: $OutputRoot"
Write-Host '   Consolidated PSM1: Maester.psm1'
Write-Host '   ORCA classes:      OrcaClasses.ps1'
Write-Host "   Public functions:  $($ExportFunctionList.Count)"
Write-Host ''
