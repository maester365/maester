BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:TempRoot = Join-Path $script:RepoRoot ".tmp-generated-file-formatting-tests-$([guid]::NewGuid())"
    $null = New-Item -Path $script:TempRoot -ItemType Directory -Force

    function Import-BuildScriptFunction {
        param (
            [Parameter(Mandatory)]
            [string] $ScriptPath,

            [Parameter(Mandatory)]
            [string[]] $FunctionName
        )

        $scriptContent = Get-Content -Path $ScriptPath -Raw
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref] $tokens, [ref] $parseErrors)

        if ($parseErrors) {
            throw "Failed to parse $ScriptPath."
        }

        foreach ($name in $FunctionName) {
            $functionDefinition = $ast.Find({
                    $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $args[0].Name -eq $name
                }, $true)

            if ($null -eq $functionDefinition) {
                throw "Function '$name' was not found in $ScriptPath."
            }

            $functionText = $functionDefinition.Extent.Text -replace "^function\s+$([regex]::Escape($name))\b", "function script:$name"
            Invoke-Expression $functionText
        }
    }

    function Assert-GeneratedPowerShellFileFormatting {
        param (
            [Parameter(Mandatory)]
            [string] $Path
        )

        $content = [System.IO.File]::ReadAllText($Path)
        $content | Should -Match "`n$"
        $content | Should -Not -Match "(\r?\n){2}$"

        foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
            $line | Should -Not -Match '[ \t]+$'
        }
    }
}

AfterAll {
    if ($script:TempRoot -and (Test-Path -LiteralPath $script:TempRoot)) {
        Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Generated PowerShell file formatting' {
    It 'keeps all tracked PowerShell files free of trailing whitespace with one final newline' {
        $powerShellFiles = & git -C $script:RepoRoot ls-files '*.ps1' '*.psd1' '*.psm1'

        foreach ($file in $powerShellFiles) {
            Assert-GeneratedPowerShellFileFormatting -Path (Join-Path $script:RepoRoot $file)
        }
    }

    It 'normalizes ORCA generated PowerShell files to one final newline' {
        Import-BuildScriptFunction `
            -ScriptPath (Join-Path $script:RepoRoot 'build/orca/Update-OrcaTests.ps1') `
            -FunctionName 'Write-OrcaGeneratedContent'

        $testRoot = Join-Path $script:TempRoot 'orca'
        $null = New-Item -Path $testRoot -ItemType Directory
        $testPath = Join-Path $testRoot 'Generated.ps1'

        Write-OrcaGeneratedContent -Path $testPath -Value "function Test-Generated {   `n    'ok'    `n}`n`n"

        Assert-GeneratedPowerShellFileFormatting -Path $testPath
    }

    It 'normalizes EIDSCA generated PowerShell files to one final newline' {
        Import-BuildScriptFunction `
            -ScriptPath (Join-Path $script:RepoRoot 'build/eidsca/Update-EidscaTests.ps1') `
            -FunctionName 'RemoveTrailingWhitespace', 'CreateFile'

        $testRoot = Join-Path $script:TempRoot 'eidsca'
        $null = New-Item -Path $testRoot -ItemType Directory

        CreateFile -folderPath $testRoot -fileName 'Generated.ps1' -content "function Test-Generated {   `n    'ok'    `n}`n`n"

        Assert-GeneratedPowerShellFileFormatting -Path (Join-Path $testRoot 'Generated.ps1')
    }
}
