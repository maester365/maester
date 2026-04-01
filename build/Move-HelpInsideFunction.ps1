<#
.SYNOPSIS
    Moves comment-based help blocks from above function definitions to inside the function body.

.DESCRIPTION
    Scans PowerShell script files (.ps1, .psm1) for functions that have their comment-based
    help placed above the function keyword rather than inside the function body. Moves the
    help block to immediately after the opening brace of the function.

    Uses the PowerShell AST for reliable parsing rather than regex.

    This is Phase 1 of the Maester module optimization plan--a prerequisite for PSM1
    consolidation (Phase 2), because external help silently breaks Get-Help when files are
    concatenated.

.PARAMETER Path
    One or more file or directory paths to process. Directories are searched recursively
    for .ps1 and .psm1 files.

.PARAMETER WhatIf
    Shows what changes would be made without actually modifying any files.

.EXAMPLE
    .\Move-HelpInsideFunction.ps1 -Path ../powershell/internal, ../powershell/public

    Processes all .ps1 files under the internal and public directories.

.EXAMPLE
    .\Move-HelpInsideFunction.ps1 -Path ../build/CommonFunctions.psm1

    Processes a single .psm1 file.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [string[]] $Path
)

# Collect all target files from the provided paths. Skip Pester test files (ending with .Tests.ps1) since they often have different formatting and we don't want to risk breaking them.
$TargetFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($InputPath in $Path) {
    $ResolvedPath = Resolve-Path -Path $InputPath -ErrorAction Stop
    if (Test-Path -Path $ResolvedPath -PathType Container) {
        $Files = Get-ChildItem -Path $ResolvedPath -Recurse -Include '*.ps1', '*.psm1' |
            Where-Object { $_.Name -notlike '*.Tests.ps1' }
        foreach ($File in $Files) {
            $TargetFiles.Add($File)
        }
    } elseif (Test-Path -Path $ResolvedPath -PathType Leaf) {
        $TargetFiles.Add((Get-Item -Path $ResolvedPath))
    }
}

$ModifiedCount = 0
$SkippedCount = 0
$ErrorCount = 0

foreach ($File in $TargetFiles) {
    try {
        $Content = Get-Content -Path $File.FullName -Raw
        if ([string]::IsNullOrWhiteSpace($Content)) {
            $SkippedCount++
            continue
        }

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $File.FullName, [ref] $Tokens, [ref] $ParseErrors
        )

        # Find all top-level function definitions in this file.
        $FunctionDefs = $Ast.FindAll({
                param($Node)
                $Node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)

        if ($FunctionDefs.Count -eq 0) {
            $SkippedCount++
            continue
        }

        # Find all comment tokens that are comment-based help (block comments starting with <#).
        $BlockComments = $Tokens | Where-Object {
            $_.Kind -eq 'Comment' -and $_.Text.StartsWith('<#')
        }

        if ($BlockComments.Count -eq 0) {
            $SkippedCount++
            continue
        }

        # Work through the file content as an array of lines for precise manipulation.
        # Use the original line endings to preserve them.
        $Lines = $Content -split '(?<=\r?\n)'

        # Build a list of transformations to apply (process in reverse order to preserve line numbers).
        $Transformations = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($FuncDef in $FunctionDefs) {
            $FuncStartLine = $FuncDef.Extent.StartLineNumber  # 1-based

            # Find a block comment that ends before this function definition starts.
            # The comment must be the closest block comment preceding the function keyword.
            $PrecedingComment = $null
            foreach ($Comment in $BlockComments) {
                $CommentEndLine = $Comment.Extent.EndLineNumber  # 1-based
                # The comment must end before the function starts (possibly with blank lines between).
                if ($CommentEndLine -lt $FuncStartLine) {
                    # Check that there is nothing but whitespace/blank lines between the comment end and function start.
                    $AllBlank = $true
                    for ($LineIdx = $CommentEndLine; $LineIdx -lt ($FuncStartLine - 1); $LineIdx++) {
                        # $LineIdx is 0-based index into the gap lines (CommentEndLine is 1-based, so line at index CommentEndLine is the line after the comment).
                        $GapLine = $Lines[$LineIdx] -replace '\r?\n$', ''
                        if ($GapLine.Trim().Length -gt 0) {
                            $AllBlank = $false
                            break
                        }
                    }
                    if ($AllBlank) {
                        $PrecedingComment = $Comment
                    }
                }
            }

            if ($null -eq $PrecedingComment) {
                # No external help found for this function (already inside or absent).
                continue
            }

            # Verify this looks like comment-based help (contains .SYNOPSIS, .DESCRIPTION, .EXAMPLE, etc.).
            if ($PrecedingComment.Text -notmatch '\.\s*(SYNOPSIS|DESCRIPTION|EXAMPLE|PARAMETER|INPUTS|OUTPUTS|NOTES|LINK|COMPONENT|ROLE|FUNCTIONALITY|FORWARDHELPTARGETNAME|FORWARDHELPCATEGORY|REMOTEHELPRUNSPACE|EXTERNALHELP)') {
                continue
            }

            # Determine the function body indentation by looking at the opening brace line.
            # The function keyword line contains the opening brace in OTBS style.
            $FuncLine = $Lines[$FuncStartLine - 1] -replace '\r?\n$', ''
            if ($FuncLine -match '\{\s*$') {
                # Opening brace is on the function line (OTBS style).
                # Body indentation = function indentation + 4 spaces.
                $FuncIndentMatch = [regex]::Match($FuncLine, '^(\s*)')
                $FuncIndent = $FuncIndentMatch.Groups[1].Value
                $BodyIndent = $FuncIndent + '    '
            } else {
                # Opening brace might be on the next line (non-OTBS). Look for it.
                $BraceLineIdx = $FuncStartLine  # 0-based index of the line after function keyword
                while ($BraceLineIdx -lt $Lines.Count) {
                    $BraceLine = $Lines[$BraceLineIdx] -replace '\r?\n$', ''
                    if ($BraceLine.Trim() -eq '{') {
                        $FuncIndentMatch = [regex]::Match($BraceLine, '^(\s*)')
                        $FuncIndent = $FuncIndentMatch.Groups[1].Value
                        $BodyIndent = $FuncIndent + '    '
                        break
                    } elseif ($BraceLine.Trim().Length -gt 0) {
                        # Non-empty, non-brace line. Unexpected, use default.
                        $BodyIndent = '    '
                        break
                    }
                    $BraceLineIdx++
                }
                if ($BraceLineIdx -ge $Lines.Count) {
                    $BodyIndent = '    '
                }
            }

            # Extract the help text content (between <# and #>), re-indent it.
            $HelpText = $PrecedingComment.Text
            # Remove the outer <# and #> delimiters.
            $InnerText = $HelpText.Substring(2)  # Remove '<#'
            if ($InnerText.EndsWith('#>')) {
                $InnerText = $InnerText.Substring(0, $InnerText.Length - 2)
            }

            # Split the inner text into lines and re-indent.
            $HelpLines = $InnerText -split '\r?\n'

            # Trim leading and trailing blank lines from the inner help content.
            while ($HelpLines.Count -gt 0 -and $HelpLines[0].Trim().Length -eq 0) {
                $HelpLines = $HelpLines[1..($HelpLines.Count - 1)]
            }
            while ($HelpLines.Count -gt 0 -and $HelpLines[-1].Trim().Length -eq 0) {
                $HelpLines = $HelpLines[0..($HelpLines.Count - 2)]
            }

            # Determine the minimum indentation of non-empty lines (to strip common leading whitespace).
            $MinIndent = [int]::MaxValue
            foreach ($HLine in $HelpLines) {
                if ($HLine.Trim().Length -gt 0) {
                    $LeadingSpaces = ($HLine -replace '^(\s*).*', '$1').Length
                    if ($LeadingSpaces -lt $MinIndent) {
                        $MinIndent = $LeadingSpaces
                    }
                }
            }
            if ($MinIndent -eq [int]::MaxValue) {
                $MinIndent = 0
            }

            # Re-indent: strip common indent, add body indent.
            $ReindentedLines = [System.Collections.Generic.List[string]]::new()
            $ReindentedLines.Add("${BodyIndent}<#")
            foreach ($HLine in $HelpLines) {
                if ($HLine.Trim().Length -eq 0) {
                    # Preserve blank lines within the help block (e.g., between sections).
                    $ReindentedLines.Add('')
                } else {
                    $Stripped = if ($MinIndent -gt 0 -and $HLine.Length -ge $MinIndent) {
                        $HLine.Substring($MinIndent)
                    } else {
                        $HLine.TrimStart()
                    }
                    $ReindentedLines.Add("${BodyIndent}${Stripped}")
                }
            }
            $ReindentedLines.Add("${BodyIndent}#>")

            $Transformations.Add(@{
                    CommentStartLine = $PrecedingComment.Extent.StartLineNumber  # 1-based
                    CommentEndLine   = $PrecedingComment.Extent.EndLineNumber    # 1-based
                    FuncStartLine    = $FuncStartLine                            # 1-based
                    ReindentedHelp   = $ReindentedLines
                    FunctionName     = $FuncDef.Name
                })
        }

        if ($Transformations.Count -eq 0) {
            $SkippedCount++
            continue
        }

        # Sort transformations in reverse line order so earlier edits don't shift later line numbers.
        $Transformations = $Transformations | Sort-Object { $_.CommentStartLine } -Descending

        # Apply transformations.
        # Work with a mutable list of lines (without line endings for easier manipulation).
        $RawLines = $Content -split '\r?\n'
        # Detect original line ending style.
        $LineEnding = if ($Content -match '\r\n') { "`r`n" } else { "`n" }

        foreach ($Transform in $Transformations) {
            $CommentStart = $Transform.CommentStartLine - 1  # 0-based
            $CommentEnd = $Transform.CommentEndLine - 1      # 0-based
            $FuncStart = $Transform.FuncStartLine - 1        # 0-based

            # Find the line with the opening brace for this function.
            $BraceLineIdx = $FuncStart
            $BraceLine = $RawLines[$BraceLineIdx]
            if ($BraceLine -match '\{\s*$') {
                # Brace is on the function line itself (OTBS).
                $InsertAfterIdx = $BraceLineIdx
            } else {
                # Look for the opening brace on subsequent lines.
                $InsertAfterIdx = $FuncStart
                for ($SearchIdx = $FuncStart + 1; $SearchIdx -lt $RawLines.Count; $SearchIdx++) {
                    if ($RawLines[$SearchIdx].Trim() -match '^\{') {
                        $InsertAfterIdx = $SearchIdx
                        break
                    }
                }
            }

            # Step 1: Insert re-indented help after the opening brace line.
            $HelpToInsert = $Transform.ReindentedHelp -as [string[]]
            $InsertPosition = $InsertAfterIdx + 1

            $Before = $RawLines[0..($InsertPosition - 1)]
            $After = if ($InsertPosition -lt $RawLines.Count) { $RawLines[$InsertPosition..($RawLines.Count - 1)] } else { @() }
            $RawLines = @($Before) + $HelpToInsert + @($After)

            # Step 2: Remove the original comment block and any blank lines between it and the function.
            # The comment block occupies lines CommentStart through CommentEnd (0-based, before insert).
            # After the insert above, the comment block is still at the same indices (we inserted after it).
            # Also remove blank lines between the comment end and the function keyword.
            $RemoveStart = $CommentStart
            $RemoveEnd = $CommentEnd
            # Extend removal to include blank lines between comment and function keyword.
            for ($BlankIdx = $CommentEnd + 1; $BlankIdx -lt ($FuncStart); $BlankIdx++) {
                if ($RawLines[$BlankIdx].Trim().Length -eq 0) {
                    $RemoveEnd = $BlankIdx
                } else {
                    break
                }
            }

            $BeforeRemove = if ($RemoveStart -gt 0) { $RawLines[0..($RemoveStart - 1)] } else { @() }
            $AfterRemove = if (($RemoveEnd + 1) -lt $RawLines.Count) { $RawLines[($RemoveEnd + 1)..($RawLines.Count - 1)] } else { @() }
            $RawLines = @($BeforeRemove) + @($AfterRemove)
        }

        # Remove any leading blank lines from the file (artifact of removing help that was at line 1).
        while ($RawLines.Count -gt 0 -and $RawLines[0].Trim().Length -eq 0) {
            $RawLines = $RawLines[1..($RawLines.Count - 1)]
        }

        # Ensure file ends with exactly one newline.
        while ($RawLines.Count -gt 0 -and $RawLines[-1].Trim().Length -eq 0) {
            $RawLines = $RawLines[0..($RawLines.Count - 2)]
        }

        $NewContent = ($RawLines -join $LineEnding) + $LineEnding

        if ($PSCmdlet.ShouldProcess($File.FullName, "Move comment-based help inside function body for: $($Transformations.FunctionName -join ', ')")) {
            Set-Content -Path $File.FullName -Value $NewContent -NoNewline -Encoding utf8BOM
            $ModifiedCount++
            foreach ($Transform in $Transformations | Sort-Object { $_.CommentStartLine }) {
                Write-Host "  Moved help inside: $($Transform.FunctionName)" -ForegroundColor Green
            }
        }
    } catch {
        $ErrorCount++
        Write-Error "Failed to process $($File.FullName): $_"
    }
}

Write-Host ''
Write-Host 'Summary:' -ForegroundColor Cyan
Write-Host "  Files modified: $ModifiedCount"
Write-Host "  Files skipped:  $SkippedCount"
Write-Host "  Errors:         $ErrorCount"
Write-Host "  Total files:    $($TargetFiles.Count)"
