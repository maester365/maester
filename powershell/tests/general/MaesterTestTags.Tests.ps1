BeforeDiscovery {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $maesterTestsPath = Join-Path $repoRoot 'tests/Maester'

    function Get-PesterBlockTag {
        param(
            [Parameter(Mandatory)]
            [System.Management.Automation.Language.CommandAst] $Command
        )

        $commandElements = $Command.CommandElements
        for ($index = 0; $index -lt $commandElements.Count; $index++) {
            $element = $commandElements[$index]
            if ($element -isnot [System.Management.Automation.Language.CommandParameterAst] -or
                $element.ParameterName -notin 'Tag', 'Tags') {
                continue
            }

            for ($tagIndex = $index + 1; $tagIndex -lt $commandElements.Count; $tagIndex++) {
                $tagElement = $commandElements[$tagIndex]
                if ($tagElement -is [System.Management.Automation.Language.CommandParameterAst] -or
                    $tagElement -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) {
                    break
                }

                try {
                    $tagElement.SafeGetValue()
                } catch {
                    # Dynamic tag expressions cannot contain the required static suite tag.
                    continue
                }
            }
        }
    }

    $script:maesterTagTestCases = foreach ($testFile in Get-ChildItem -Path $maesterTestsPath -Filter '*.Tests.ps1' -File -Recurse) {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $testFile.FullName,
            [ref] $tokens,
            [ref] $parseErrors
        )

        if ($parseErrors) {
            throw "Failed to parse $($testFile.FullName): $($parseErrors.Message -join '; ')"
        }

        $testCommands = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'It'
            }, $true)

        foreach ($testCommand in $testCommands) {
            $testHeader = $testCommand.CommandElements |
                Where-Object { $_ -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst] } |
                ForEach-Object { $_.Extent.Text }
            $testId = [regex]::Match(($testHeader -join ' '), '(?i)\bMT\.?\d{4,5}(?:\.\d+)*').Value

            if (-not $testId) {
                continue
            }

            $ancestorTags = @()
            $ancestor = $testCommand.Parent
            while ($null -ne $ancestor) {
                if ($ancestor -is [System.Management.Automation.Language.CommandAst] -and
                    $ancestor.GetCommandName() -in 'Describe', 'Context') {
                    $ancestorTags += Get-PesterBlockTag -Command $ancestor
                }
                $ancestor = $ancestor.Parent
            }

            [pscustomobject]@{
                TestId             = $testId
                RelativePath       = [System.IO.Path]::GetRelativePath($repoRoot, $testFile.FullName)
                Line               = $testCommand.Extent.StartLineNumber
                HasMaesterSuiteTag = $ancestorTags -contains 'Maester'
            }
        }
    }
}

Describe 'Maester test tags' {
    It '<_.TestId> in <_.RelativePath>:<_.Line> inherits the Maester suite tag' -ForEach $script:maesterTagTestCases {
        $_.HasMaesterSuiteTag | Should -BeTrue -Because 'every MT test must run when Invoke-Maester is filtered with -Tag Maester'
    }
}
