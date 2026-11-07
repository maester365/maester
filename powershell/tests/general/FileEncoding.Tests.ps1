# Guards the encoding rule in website/docs/contributing.md: every PowerShell file (.ps1, .psm1, .psd1) is UTF-8 with
# a byte order mark, and the tools that write PowerShell files keep to it. Markdown and JSON have no byte order mark.
# PSScriptAnalyzer's PSUseBOMForUnicodeEncodedFile only sees files that contain non-ASCII text, so this test checks
# the bytes itself.
BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    function Test-Utf8Bom {
        param([Parameter(Mandatory)] [string] $Path)
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $buffer = [byte[]]::new(3)
            $read = $stream.Read($buffer, 0, 3)
            $read -eq 3 -and $buffer[0] -eq 0xEF -and $buffer[1] -eq 0xBB -and $buffer[2] -eq 0xBF
        } finally {
            $stream.Dispose()
        }
    }

    function Import-BuildScriptFunction {
        param (
            [Parameter(Mandatory)] [string] $ScriptPath,
            [Parameter(Mandatory)] [string[]] $FunctionName
        )
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref] $tokens, [ref] $parseErrors)
        if ($parseErrors) { throw "Failed to parse $ScriptPath." }
        foreach ($name in $FunctionName) {
            $definition = $ast.Find({
                    $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq $name
                }, $true)
            if ($null -eq $definition) { throw "Function '$name' was not found in $ScriptPath." }
            . ([scriptblock]::Create(($definition.Extent.Text -replace "^function\s+$([regex]::Escape($name))\b", "function script:$name")))
        }
    }
}

Describe 'PowerShell file encoding' {
    It 'saves every tracked PowerShell file as UTF-8 with a byte order mark' {
        $files = @(git -C $script:RepoRoot ls-files '*.ps1' '*.psm1' '*.psd1')
        $files.Count | Should -BeGreaterThan 0
        $missing = @($files | Where-Object { -not (Test-Utf8Bom -Path (Join-Path $script:RepoRoot $_)) })
        $because = "these files need a byte order mark. Fix each one with: `$c = Get-Content <path> -Raw; Set-Content <path> -Value `$c -NoNewline -Encoding utf8BOM"
        $missing | Should -BeNullOrEmpty -Because $because
    }

    It 'New-MtTest writes the test with a byte order mark and the guide without one' {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
        $folder = Join-Path $TestDrive 'new-mttest'
        $null = New-MtTest -Id CONTOSO.1001 -Title 'Café check' -Service None -Path $folder -Confirm:$false
        Test-Utf8Bom -Path (Join-Path $folder 'Test.CONTOSO.1001.ps1') | Should -BeTrue
        Test-Utf8Bom -Path (Join-Path $folder 'Test.CONTOSO.1001.md') | Should -BeFalse
    }

    It 'the ORCA generator writes PowerShell files with a byte order mark and Markdown without one' {
        Import-BuildScriptFunction -ScriptPath (Join-Path $script:RepoRoot 'build/orca/Update-OrcaTests.ps1') -FunctionName 'Write-OrcaGeneratedContent'
        $ps1 = Join-Path $TestDrive 'orca.ps1'
        $md = Join-Path $TestDrive 'orca.md'
        Write-OrcaGeneratedContent -Path $ps1 -Value "function Test-Generated { 'ok' }`n"
        Write-OrcaGeneratedContent -Path $md -Value "# Generated`n"
        Test-Utf8Bom -Path $ps1 | Should -BeTrue
        Test-Utf8Bom -Path $md | Should -BeFalse
    }

    It 'the EIDSCA generator writes PowerShell files with a byte order mark and Markdown without one' {
        Import-BuildScriptFunction -ScriptPath (Join-Path $script:RepoRoot 'build/eidsca/Update-EidscaTests.ps1') -FunctionName 'RemoveTrailingWhitespace', 'CreateFile'
        CreateFile -folderPath $TestDrive -fileName 'eidsca.ps1' -content "function Test-Generated { 'ok' }`n"
        CreateFile -folderPath $TestDrive -fileName 'eidsca.md' -content "# Generated`n"
        Test-Utf8Bom -Path (Join-Path $TestDrive 'eidsca.ps1') | Should -BeTrue
        Test-Utf8Bom -Path (Join-Path $TestDrive 'eidsca.md') | Should -BeFalse
    }
}
