function Get-MtPesterFileInventory {
    <#
    .SYNOPSIS
    Lists the It blocks of Pester test files by reading their AST, without running them.

    .DESCRIPTION
    Used by the engine to select Pester-format tests by ID (design section 8). The ID of an It block
    is the text before the first colon of its name, or the whole name. A name that is built at run
    time (a '<template>' or an expandable string) has no static ID; its literal prefix is recorded so
    the test can be matched as a family.

    Each row has: File, Line, Id (or $null), Name, IsStatic, LiteralPrefix, Tags (the It tags plus the
    tags of every enclosing Describe and Context), HasForEach, and Block (the name of the nearest
    enclosing Describe). A file that does not parse gives one row with ParseError set.

    .EXAMPLE
    Get-MtPesterFileInventory -Path ./tests

    Lists every It block of every *.Tests.ps1 file under ./tests.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Files or folders to scan. Folders are scanned recursively for *.Tests.ps1 files.
        [Parameter(Mandatory)]
        [string[]] $Path
    )

    $files = foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            Get-Item -LiteralPath $p
        } elseif (Test-Path -LiteralPath $p -PathType Container) {
            Get-ChildItem -LiteralPath $p -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue
        }
    }

    foreach ($file in ($files | Sort-Object FullName -Unique)) {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors) {
            [pscustomobject]@{
                File          = $file.FullName
                Line          = $null
                Id            = $null
                Name          = $null
                IsStatic      = $false
                LiteralPrefix = $null
                Tags          = @()
                HasForEach    = $false
                Block         = $null
                ParseError    = ($parseErrors | Select-Object -First 1).Message
            }
            # The IDs of a file that does not parse can still be read from the It names that did.
        }

        $blockCommands = @('Describe', 'Context', 'It')
        $commands = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -in $blockCommands
            }, $true)

        foreach ($it in ($commands | Where-Object { $_.GetCommandName() -eq 'It' })) {
            $info = Get-MtPesterBlockArgument -CommandAst $it
            $nameAst = $info.NameAst

            $name = $null
            $isStatic = $false
            $literalPrefix = $null
            if ($nameAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                $name = $nameAst.Value
                $isStatic = $name -notmatch '<[^>]+>'
                $literalPrefix = if ($isStatic) { $name } else { $name.Substring(0, $name.IndexOf('<')) }
            } elseif ($nameAst -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                $name = $nameAst.Value
                $firstDynamic = @($nameAst.NestedExpressions | ForEach-Object { $_.Extent.StartOffset - $nameAst.Extent.StartOffset - 1 }) +
                    @(if ($name -match '<') { $name.IndexOf('<') }) | Where-Object { $_ -ge 0 } | Sort-Object | Select-Object -First 1
                $literalPrefix = if ($null -ne $firstDynamic) { $name.Substring(0, [Math]::Min($firstDynamic, $name.Length)) } else { $name }
            }

            $id = $null
            if ($isStatic) {
                $id = if ($name.Contains(':')) { ($name -split ':', 2)[0].Trim() } else { $name.Trim() }
            }

            # Tags and names of the enclosing blocks, innermost last.
            $tags = [System.Collections.Generic.List[string]]::new()
            $block = $null
            $parent = $it.Parent
            $ancestors = [System.Collections.Generic.List[object]]::new()
            while ($parent) {
                if ($parent -is [System.Management.Automation.Language.CommandAst] -and $parent.GetCommandName() -in 'Describe', 'Context') {
                    $ancestors.Insert(0, $parent)
                }
                $parent = $parent.Parent
            }
            foreach ($ancestor in $ancestors) {
                $ancestorInfo = Get-MtPesterBlockArgument -CommandAst $ancestor
                foreach ($t in $ancestorInfo.Tags) { $tags.Add($t) }
                if ($ancestor.GetCommandName() -eq 'Describe' -and $ancestorInfo.NameAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $block = $ancestorInfo.NameAst.Value
                }
            }
            foreach ($t in $info.Tags) { $tags.Add($t) }

            [pscustomobject]@{
                File          = $file.FullName
                Line          = $it.Extent.StartLineNumber
                Id            = $id
                Name          = $name
                IsStatic      = $isStatic
                LiteralPrefix = $literalPrefix
                Tags          = @($tags | Select-Object -Unique)
                HasForEach    = $info.HasForEach -or ($ancestors | Where-Object { (Get-MtPesterBlockArgument -CommandAst $_).HasForEach }).Count -gt 0
                Block         = $block
                ParseError    = $null
            }
        }
    }
}

function Get-MtPesterBlockArgument {
    <#
    .SYNOPSIS
    Reads the name, tags and -ForEach/-TestCases presence of a Describe, Context or It command from its AST.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.CommandAst] $CommandAst
    )

    $nameAst = $null
    $tags = [System.Collections.Generic.List[string]]::new()
    $hasForEach = $false
    $elements = $CommandAst.CommandElements
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $element = $elements[$i]
        if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
            $parameterName = $element.ParameterName
            $argument = $element.Argument
            if (-not $argument -and $i + 1 -lt $elements.Count -and $elements[$i + 1] -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                $i++
                $argument = $elements[$i]
            }
            if ($parameterName -like 'Ta*' -and $argument) {
                foreach ($value in (Get-MtAstConstantString -Ast $argument)) { $tags.Add($value) }
            } elseif ($parameterName -like 'N*' -and $argument -and -not $nameAst) {
                $nameAst = $argument
            } elseif ($parameterName -in 'ForEach', 'TestCases', 'Foreach') {
                $hasForEach = $true
            }
        } elseif (-not $nameAst -and $element -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst]) {
            $nameAst = $element
        }
    }

    [pscustomobject]@{
        NameAst    = $nameAst
        Tags       = $tags.ToArray()
        HasForEach = $hasForEach
    }
}

function Get-MtAstConstantString {
    <#
    .SYNOPSIS
    Returns the constant string values of an AST node: a string, or an array of strings. Non-constant parts are ignored.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.Ast] $Ast
    )

    if ($Ast -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return $Ast.Value
    }
    # Strings inside an array literal or a parenthesised list. A tag computed at run time ("$($_.Name)")
    # has no static value, so constants inside member access, sub-expressions or commands are skipped.
    $dynamic = [System.Management.Automation.Language.MemberExpressionAst], [System.Management.Automation.Language.SubExpressionAst],
    [System.Management.Automation.Language.ExpandableStringExpressionAst], [System.Management.Automation.Language.CommandAst]
    $constants = $Ast.FindAll({
            param($node)
            if ($node -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { return $false }
            for ($p = $node.Parent; $p -and $p -ne $Ast.Parent; $p = $p.Parent) {
                foreach ($type in $dynamic) { if ($p -is $type) { return $false } }
            }
            $true
        }, $true)
    foreach ($c in $constants) { $c.Value }
}
