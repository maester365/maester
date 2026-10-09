<#
.SYNOPSIS
    Builds the Maester PowerShell module into a consolidated, publishable artifact.

.DESCRIPTION
    Consolidates all source files from powershell/internal/ and powershell/public/ into
    a single Maester.psm1, consolidates ORCA class definitions into OrcaClasses.ps1,
    auto-generates the FunctionsToExport list and companion Markdown metadata, and
    copies static assets and tests into the output directory.

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

function Format-ParseErrorSummary {
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.ParseError[]] $ParseError,

        [Parameter(Mandatory)]
        [string] $Path
    )

    $ParseErrorMessages = @($ParseError | Select-Object -First 5 | ForEach-Object {
            "line $($_.Extent.StartLineNumber), column $($_.Extent.StartColumnNumber): $($_.Message)"
        })

    $Summary = "Parse error in '$Path' ($($ParseError.Count) error(s)): $($ParseErrorMessages -join '; ')"
    if ($ParseError.Count -gt $ParseErrorMessages.Count) {
        $Summary += "; $($ParseError.Count - $ParseErrorMessages.Count) additional error(s) not shown"
    }

    return $Summary
}

function Get-PowerShellAst {
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    $Tokens = $null
    $ParseErrors = $null
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$Tokens, [ref]$ParseErrors
    )

    if ($ParseErrors.Count -gt 0) {
        throw (Format-ParseErrorSummary -ParseError $ParseErrors -Path $Path)
    }

    return $Ast
}

function Get-ParenthesisBalance {
    param (
        [Parameter(Mandatory)]
        [string] $Text
    )

    return ([regex]::Matches($Text, '\(').Count - [regex]::Matches($Text, '\)').Count)
}

function Set-Utf8BomContent {
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Value
    )

    $Utf8BomEncoding = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText($Path, $Value, $Utf8BomEncoding)
}

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

$PublicSourceFiles = @(Get-ChildItem -Path "$SourceRoot/public" -Filter '*.ps1' -Recurse |
    Where-Object { $_.Name -notlike '*.Tests.ps1' } |
        Sort-Object -Property FullName)

$ApprovedVerbs = (Get-Verb).Verb

$ExportFunctionList = [System.Collections.Generic.List[string]]::new()

foreach ($File in $PublicSourceFiles) {
    $Ast = Get-PowerShellAst -Path $File.FullName

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

$InternalFiles = @(Get-ChildItem -Path "$SourceRoot/internal" -Filter '*.ps1' -Recurse |
    Where-Object {
        $_.Name -notlike '*.Tests.ps1' -and
        $_.Name -notlike 'check-ORCA*.ps1'
    } |
        Sort-Object -Property FullName)

$PublicFiles = @(Get-ChildItem -Path "$SourceRoot/public" -Filter '*.ps1' -Recurse |
    Where-Object { $_.Name -notlike '*.Tests.ps1' } |
        Sort-Object -Property FullName)

Write-Host "   Internal files: $($InternalFiles.Count)"
Write-Host "   Public files:   $($PublicFiles.Count)"

# Helper: compute directory depth of a file relative to $SourceRoot.
# e.g. powershell/internal/engine/Read-MtNativeTest.ps1 → depth 2, powershell/public/services/entra/Get-MtUser.ps1 → depth 3
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
    $ParamPattern = '^\s*param\s*\('
    $UsingModulePattern = '^\s*using\s+module\s+'
    $GeneratedPattern = '^\s*#\s*Generated by'

    $Lines = $Content -split "`n"
    $Result = [System.Collections.Generic.List[string]]::new($Lines.Count)
    $StrippedItems = [System.Collections.Generic.List[string]]::new()
    $InPreamble = $true
    $InParamBlock = $false
    $ParamBlockBalance = 0

    foreach ($Line in $Lines) {
        if ($InPreamble) {
            # While in the preamble region, skip lines matching preamble patterns.
            # Stop the preamble at the first line that is actual code (function,
            # class, or any non-blank, non-comment, non-preamble line).
            $Trimmed = $Line.Trim()

            if ($InParamBlock) {
                $ParamBlockBalance += Get-ParenthesisBalance -Text $Line
                if ($ParamBlockBalance -le 0) {
                    $InParamBlock = $false
                }
                continue
            }

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
                $StrippedItems.Add('param block')
                $ParamBlockBalance = Get-ParenthesisBalance -Text $Line
                if ($ParamBlockBalance -gt 0) {
                    $InParamBlock = $true
                }
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

# Helper: extract the module preamble from source Maester.psm1 so the session
# initialization block is maintained in one place only.
function Get-ModulePreambleFromSource {
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Source file was not found at '$Path'."
        }

        $Item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($Item.PSIsContainer) {
            throw "Expected a file path but received a directory: '$Path'. Pass the full path to Maester.psm1."
        }

        $Content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($Content)) {
            throw "Source file '$Path' is empty."
        }

        $PreambleMatch = [regex]::Match(
            $Content,
            '(?s)\A.*?New-Variable\s+-Name\s+__MtSession\s+-Value\s+\$__MtSession\s+-Scope\s+Script\s+-Force\s*'
        )

        if (-not $PreambleMatch.Success) {
            throw "Could not locate the __MtSession initialization block in '$Path'."
        }

        return $PreambleMatch.Value.TrimEnd("`r", "`n")
    } catch {
        $Detail = $_.Exception.Message
        throw "Failed to extract module preamble from '$Path'. $Detail"
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
$ModulePreamble = Get-ModulePreambleFromSource -Path (Join-Path $SourceRoot 'Maester.psm1')
$null = $Builder.AppendLine($ModulePreamble)

# Load the ORCA classes (written to OrcaClasses.ps1 in Phase D) into the module's own scope.
# They used to be ScriptsToProcess, which defines them in the scope of whoever imports the
# module: when that is a script (Build-LocalMaester.ps1, a CI step), the classes disappear when
# the script ends and every ORCA check fails with "Cannot find type [PolicyInfo]".
$null = $Builder.AppendLine()
$null = $Builder.AppendLine('. "$PSScriptRoot/OrcaClasses.ps1"')

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

# Built-in native tests (tests/**/Test.<ID>.ps1) are module source: their functions are defined in module
# scope, after internal and public functions (Maester 3.0 design, section 3.1).
$NativeTestFiles = @(Get-ChildItem -Path $TestsRoot -Filter 'Test.*.ps1' -Recurse -File |
        Where-Object { $_.FullName -notmatch '[\\/]Custom[\\/]' } |
        Sort-Object -Property FullName)
Write-Information "   Native test files: $($NativeTestFiles.Count)" -InformationAction Continue
$null = $Builder.AppendLine('#region Built-in Native Tests')
$null = $Builder.AppendLine()
foreach ($File in $NativeTestFiles) {
    $FileContent = Get-Content -Path $File.FullName -Raw
    $FileContent = Remove-FileLevelPreamble -Content $FileContent -FileName $File.Name
    $null = $Builder.AppendLine("# ── $($File.Name) ──")
    $null = $Builder.AppendLine($FileContent.TrimEnd())
    $null = $Builder.AppendLine()
}
$null = $Builder.AppendLine('#endregion Built-in Native Tests')
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
Set-Utf8BomContent -Path $OutputPsm1 -Value $Builder.ToString()
Write-Host '   Written: Maester.psm1'
$null = Get-PowerShellAst -Path $OutputPsm1
Write-Host '   Validated: Maester.psm1 syntax'

# ──────────────────────────────────────────────────────────────────────────────
# Phase D — Consolidate ORCA class files into OrcaClasses.ps1
# ──────────────────────────────────────────────────────────────────────────────

Write-Host '── Phase D: Consolidating ORCA classes' -ForegroundColor Cyan

$OrcaBuilder = [System.Text.StringBuilder]::new()

# Base classes and enums from orcaClass.psm1 — must come first (defines all base
# types before any derived check classes).
$OrcaClassPath = Join-Path $SourceRoot 'internal/generated/orca/orcaClass.psm1'
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
$OrcaCheckFiles = @(Get-ChildItem -Path "$SourceRoot/internal/generated/orca" -Filter 'check-ORCA*.ps1' -Recurse |
    Sort-Object -Property FullName)

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
Set-Utf8BomContent -Path $OutputOrcaClasses -Value $OrcaBuilder.ToString()
Write-Host "   Written: OrcaClasses.ps1 ($($OrcaCheckFiles.Count) check classes)"
$null = Get-PowerShellAst -Path $OutputOrcaClasses
Write-Host '   Validated: OrcaClasses.ps1 syntax'

# ──────────────────────────────────────────────────────────────────────────────
# Phase E — Generate test metadata and copy static assets (must run before
#           manifest update so that FormatsToProcess references can be validated)
# ──────────────────────────────────────────────────────────────────────────────

Write-Information '── Phase E: Generating test metadata and copying static assets' -InformationAction Continue

# Companion Markdown is authored next to individual function files, but those
# functions are consolidated into Maester.psm1 in the published module. Bundle
# each paired .ps1/.md file by function name so runtime lookups do not depend on
# the source directory layout.
$TestMetadata = [ordered]@{}
$MarkdownFiles = @(Get-ChildItem -Path "$SourceRoot/internal", "$SourceRoot/public" -Filter '*.md' -Recurse |
        Sort-Object -Property FullName)

foreach ($MarkdownFile in $MarkdownFiles) {
    $ScriptPath = [System.IO.Path]::ChangeExtension($MarkdownFile.FullName, '.ps1')
    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        continue
    }

    $FunctionName = $MarkdownFile.BaseName
    if ($TestMetadata.Contains($FunctionName)) {
        throw "Duplicate companion Markdown metadata key '$FunctionName' found at '$($MarkdownFile.FullName)'."
    }

    $Content = Get-Content -LiteralPath $MarkdownFile.FullName -Raw -ErrorAction Stop
    $SplitContent = $Content -split '<!--- Results --->', 2
    $TestMetadata[$FunctionName] = [ordered]@{
        Description = $SplitContent[0]
        Result = if ($SplitContent.Count -gt 1) { $SplitContent[1] } else { $null }
    }
}

# Built-in native tests: validate them, write the catalog, and bundle each test's Markdown by ID
# (design appendix A.4). The build fails on a schema error, a duplicate ID or function name, a missing
# .md file or an unknown licence token.
# The source module is imported in a separate runspace, so the caller's session (which may itself have
# Maester loaded, as in the module's own tests) is not changed.
$CatalogResult = [pscustomobject]@{ Tests = @(); Problems = @(); Suites = @{}; Version = $SourceManifest.ModuleVersion; GraphScope = @() }
if ($NativeTestFiles.Count -gt 0) { $CatalogRunspace = [powershell]::Create(); try {
    $null = $CatalogRunspace.AddScript({
            param($SourceManifest, $TestsRoot)
            $module = Import-Module $SourceManifest -Force -PassThru -WarningAction SilentlyContinue -ErrorAction Stop |
                Where-Object { $_.Name -eq 'Maester' } | Select-Object -First 1
            & $module {
                param($TestsRoot)
                $tests = @(Get-MtNativeTestInventory -Path $TestsRoot -Root $TestsRoot -BuiltIn)
                $licenseTokens = @((Get-MtLicenseTable).Tokens.Keys)
                $problems = foreach ($t in $tests) {
                    foreach ($e in $t.Errors) { "$($t.File):$($e.Line): $($e.Message)" }
                    if (-not $t.MarkdownPath) { "$($t.File): the test has no Markdown file." }
                    foreach ($element in @($t.License)) {
                        foreach ($token in ($element -split '&')) {
                            if ($token -and -not ($licenseTokens | Where-Object { $_ -eq $token })) { "$($t.File): licence token '$token' is not in the licence table." }
                        }
                    }
                }
                $suites = @{}
                foreach ($manifest in Get-ChildItem -Path $TestsRoot -Filter 'suite.json' -Recurse -File) {
                    $suite = Get-Content -LiteralPath $manifest.FullName -Raw | ConvertFrom-Json
                    if ($suite.Id) { $suites[[string]$suite.Id] = $suite }
                }
                [pscustomobject]@{
                    Tests      = $tests
                    Problems   = @($problems)
                    Suites     = $suites
                    Version    = (Get-MtModuleVersion)
                    GraphScope = @(Get-MtGraphScope)
                }
            } $TestsRoot
        }).AddArgument((Join-Path $SourceRoot 'Maester.psd1')).AddArgument($TestsRoot)
    $CatalogResult = $CatalogRunspace.Invoke() | Select-Object -Last 1
    if ($CatalogRunspace.HadErrors -and -not $CatalogResult) {
        throw "Could not read the built-in native tests: $($CatalogRunspace.Streams.Error | Select-Object -First 1)"
    }
} finally {
    $CatalogRunspace.Dispose()
} }
if ($CatalogResult.Problems.Count -gt 0) {
    throw "Built-in native tests have $($CatalogResult.Problems.Count) problem(s):`n$($CatalogResult.Problems -join "`n")"
}
$RepoRootForCatalog = Split-Path -Path $TestsRoot -Parent
$CatalogTests = foreach ($t in ($CatalogResult.Tests | Sort-Object Id)) {
    $Relative = $t.File.Substring($RepoRootForCatalog.Length).TrimStart('\', '/') -replace '\\', '/'
    $Entry = [ordered]@{}
    foreach ($Property in $t.PSObject.Properties) {
        if ($Property.Name -in 'Errors', 'MarkdownPath', 'BuiltIn') { continue }
        $Entry[$Property.Name] = $Property.Value
    }
    $Entry.File = $Relative
    $Entry.IdPattern = if ($t.InstanceSource) { '^' + [regex]::Escape($t.Id) + '\.[A-Za-z0-9][A-Za-z0-9._-]{0,127}$' } else { $null }
    [pscustomobject]$Entry

    # Markdown by ID, and by function name for 2.x-style lookups.
    $MarkdownContent = Get-Content -LiteralPath $t.MarkdownPath -Raw
    $MarkdownParts = $MarkdownContent -split '<!--- Results --->', 2
    $MarkdownEntry = [ordered]@{ Description = $MarkdownParts[0]; Result = if ($MarkdownParts.Count -gt 1) { $MarkdownParts[1] } else { $null } }
    $TestMetadata[$t.Id] = $MarkdownEntry
    if (-not $TestMetadata.Contains($t.FunctionName)) { $TestMetadata[$t.FunctionName] = $MarkdownEntry }
}
$Catalog = [ordered]@{
    SchemaVersion    = '1.0'
    CatalogVersion   = [string]$CatalogResult.Version
    GraphPermissions = $CatalogResult.GraphScope
    Suites           = $CatalogResult.Suites
    Tests            = @($CatalogTests)
}
$CatalogPath = Join-Path $OutputRoot 'Maester.TestCatalog.json'
Set-Utf8BomContent -Path $CatalogPath -Value ($Catalog | ConvertTo-Json -Depth 8)
Write-Information "   Generated: Maester.TestCatalog.json ($(@($CatalogTests).Count) native tests)" -InformationAction Continue

$TestMetadataPath = Join-Path $OutputRoot 'Maester.TestMetadata.json'
$TestMetadataJson = $TestMetadata | ConvertTo-Json -Depth 3
Set-Utf8BomContent -Path $TestMetadataPath -Value $TestMetadataJson
Write-Information "   Generated: Maester.TestMetadata.json ($($TestMetadata.Count) entries)" -InformationAction Continue

# Assets directory
$AssetsSource = Join-Path $SourceRoot 'assets'
$AssetsOutput = Join-Path $OutputRoot 'assets'
Copy-Item -Path $AssetsSource -Destination $AssetsOutput -Recurse -Force
Write-Host '   Copied: assets/'

# Engine DLL (committed prebuilt; see build/Build-MaesterEngine.ps1)
$LibSource = Join-Path $SourceRoot 'lib'
$LibOutput = Join-Path $OutputRoot 'lib'
Copy-Item -Path $LibSource -Destination $LibOutput -Recurse -Force
Write-Information '   Copied: lib/' -InformationAction Continue

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

# Update FunctionsToExport in the output manifest. OrcaClasses.ps1 is dot-sourced by
# Maester.psm1 itself (see Phase C), not listed in ScriptsToProcess.
Update-ModuleManifest -Path $OutputManifest `
    -FunctionsToExport $ExportFunctionList.ToArray()

Write-Host "   FunctionsToExport: $($ExportFunctionList.Count) functions"

# ──────────────────────────────────────────────────────────────────────────────
# Phase G — Copy the built-in Pester test suites, preserving Pester file boundaries
# ──────────────────────────────────────────────────────────────────────────────
# Built-in tests run from the module (Maester 3.0 design, section 7.2). Suites that are not yet
# migrated to the native format ship as Pester files in builtin-pester/. The Custom folder is the
# user's and is not shipped; Install-MaesterTests writes its README from assets/templates.

Write-Information '── Phase G: Copying built-in test suites' -InformationAction Continue

$TestsOutput = Join-Path $OutputRoot 'builtin-pester'
$null = New-Item -Path $TestsOutput -ItemType Directory -Force
Get-ChildItem -LiteralPath $TestsRoot -Force | Where-Object { $_.Name -ine 'Custom' } |
    Copy-Item -Destination $TestsOutput -Recurse -Force
# Native tests are compiled into Maester.psm1 and their Markdown is bundled; they are not copied here.
Get-ChildItem -LiteralPath $TestsOutput -Recurse -File | Where-Object { $_.Name -like 'Test.*.ps1' -or $_.Name -like 'Test.*.md' } |
    Remove-Item -Force
Write-Information '   Copied: tests/ → builtin-pester/ (without Custom/)' -InformationAction Continue

# ──────────────────────────────────────────────────────────────────────────────
# Phase H — Build profiling (optional)
# ──────────────────────────────────────────────────────────────────────────────

if ($Profile) {
    Write-Host '── Phase H: Profiling module import' -ForegroundColor Cyan

    $OutputManifestPath = Join-Path $OutputRoot 'Maester.psd1'
    $ImportTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $ImportedModules = @(Import-Module $OutputManifestPath -Force -ErrorAction Stop -PassThru)
    $ImportTimer.Stop()

    $ImportedModule = $ImportedModules | Where-Object { $_.Name -eq 'Maester' } | Select-Object -First 1
    if (-not $ImportedModule) {
        throw 'Import-Module did not return the Maester module object.'
    }

    $CommandCount = $ImportedModule.ExportedCommands.Count

    Write-Host "   Import time:     $([math]::Round($ImportTimer.Elapsed.TotalSeconds, 3))s"
    Write-Host "   Exported commands: $CommandCount"

    $ImportedModules | Remove-Module -Force -ErrorAction SilentlyContinue
}

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '── Build complete' -ForegroundColor Green
Write-Host "   Output directory: $OutputRoot"
Write-Host '   Consolidated PSM1: Maester.psm1'
Write-Information '   Test metadata:     Maester.TestMetadata.json' -InformationAction Continue
Write-Host '   ORCA classes:      OrcaClasses.ps1'
Write-Host "   Public functions:  $($ExportFunctionList.Count)"
Write-Host ''
