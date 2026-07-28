BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:EidscaBuildScript = Join-Path $script:RepoRoot 'build/eidsca/Update-EidscaTests.ps1'

    $scriptContent = Get-Content -Path $script:EidscaBuildScript -Raw
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $scriptContent,
        [ref] $tokens,
        [ref] $parseErrors
    )

    if ($parseErrors) {
        throw "Failed to parse $script:EidscaBuildScript."
    }

    $functionName = 'ConvertTo-LanguageNeutralMicrosoftUrl'
    $functionDefinition = $ast.Find({
            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $args[0].Name -eq $functionName
        }, $true)

    if ($null -eq $functionDefinition) {
        throw "Function '$functionName' was not found in $script:EidscaBuildScript."
    }

    $functionText = $functionDefinition.Extent.Text -replace `
        "^function\s+$([regex]::Escape($functionName))\b", `
        "function script:$functionName"
    . ([scriptblock]::Create($functionText))

    $languageNeutralDomains = @(
        'developer.microsoft.com'
        'docs.microsoft.com'
        'learn.microsoft.com'
        'support.microsoft.com'
        'www.microsoft.com'
    )
    $domainPattern = ($languageNeutralDomains | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $script:LanguageSpecificUrlPattern = '(?i)https?://(?:' + $domainPattern + ')/[a-z]{2}-[a-z]{2}(?=/|[?#\s)\]}>.,;:''"]|$)'
}

Describe 'Language-neutral Microsoft URLs' {
    It 'removes language segments from supported Microsoft URLs' {
        $testCases = @(
            @{
                Input    = 'https://learn.microsoft.com/' + 'en-us/entra/identity?view=entra#overview'
                Expected = 'https://learn.microsoft.com/entra/identity?view=entra#overview'
            }
            @{
                Input    = 'https://learn.microsoft.com/' + 'de-de/graph/api/resources/user'
                Expected = 'https://learn.microsoft.com/graph/api/resources/user'
            }
            @{
                Input    = 'https://developer.microsoft.com/' + 'en-us/graph/graph-explorer'
                Expected = 'https://developer.microsoft.com/graph/graph-explorer'
            }
            @{
                Input    = 'https://docs.microsoft.com/' + 'en-us/windows/reference'
                Expected = 'https://docs.microsoft.com/windows/reference'
            }
            @{
                Input    = 'See https://support.microsoft.com/' + 'en-us/topic/example for details.'
                Expected = 'See https://support.microsoft.com/topic/example for details.'
            }
            @{
                Input    = 'https://www.microsoft.com/' + 'en-us/security'
                Expected = 'https://www.microsoft.com/security'
            }
        )

        foreach ($testCase in $testCases) {
            ConvertTo-LanguageNeutralMicrosoftUrl -Content $testCase.Input |
                Should -Be $testCase.Expected
        }
    }

    It 'does not change unsupported domains or language-neutral URLs' {
        $testCases = @(
            'https://example.com/en-us/reference'
            'https://learn.microsoft.com/entra/identity'
            'https://developer.microsoft.com/graph/graph-explorer'
        )

        foreach ($testCase in $testCases) {
            ConvertTo-LanguageNeutralMicrosoftUrl -Content $testCase |
                Should -Be $testCase
        }
    }

    It 'keeps all tracked PowerShell and Markdown source files language neutral' {
        $sourceRoots = @('build/eidsca/', 'powershell/', 'tests/')
        $trackedFiles = & git -C $script:RepoRoot ls-files '*.ps1' '*.md'
        $sourceFiles = $trackedFiles | Where-Object {
            $file = $_
            $sourceRoots | Where-Object { $file.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }
        }

        $violations = foreach ($relativePath in $sourceFiles) {
            $lineNumber = 0
            foreach ($line in Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath)) {
                $lineNumber++
                if ($line -match $script:LanguageSpecificUrlPattern) {
                    "${relativePath}:${lineNumber}: $($Matches[0])"
                }
            }
        }

        $violations | Should -BeNullOrEmpty -Because (
            'supported Microsoft URLs should rely on browser language detection: ' +
            ($violations -join ', ')
        )
    }
}
