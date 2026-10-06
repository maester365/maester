BeforeAll {
    $script:manifest = (Resolve-Path "$PSScriptRoot/../../../Maester.psd1").Path
    Import-Module $script:manifest -Force -WarningAction SilentlyContinue
}

Describe 'XML test result file' {
    It 'Drops characters XML cannot hold and keeps the rest' {
        $text = InModuleScope Maester { ConvertTo-MtXmlSafeString "Policy$([char]1)Name <&> $([char]0xD83D)$([char]0xDE00) $([char]0xD800)" }
        $text | Should -Be "PolicyName <&> $([char]0xD83D)$([char]0xDE00) "
    }

    It 'Writes a valid file when a message holds a control character' {
        $path = Join-Path $TestDrive 'results.xml'
        $results = [pscustomobject]@{
            ExecutedAt = (Get-Date).ToString('o')
            Tests      = @([pscustomobject]@{
                    Id = 'X.1'; Name = "X.1: Policy$([char]1)Name"; Block = 'Custom'; Result = 'Failed'; Duration = '00:00:01'
                    ResultDetail = [pscustomobject]@{ TestResult = "Could not read Policy$([char]1)Name" }; ReasonCode = $null; ReasonDetail = $null
                })
        }
        foreach ($format in 'NUnitXml', 'JUnitXml') {
            InModuleScope Maester -Parameters @{ R = $results; P = $path; F = $format } { Export-MtTestResultXml -MaesterResults $R -Path $P -Format $F }
            { [xml](Get-Content -LiteralPath $path -Raw) } | Should -Not -Throw -Because $format
            Get-Content -LiteralPath $path -Raw | Should -Match 'PolicyName'
        }
    }
}

Describe 'Config found by folder discovery' {
    BeforeAll {
        # parent/maester-config.json sits above the test folder parent/run and asks for the XML file outside it.
        $script:parent = Join-Path $TestDrive 'parent'
        $script:run = Join-Path $script:parent 'run'
        $null = New-Item -ItemType Directory -Path $script:run -Force
        "Describe 'C' { It 'C.1: c' { `$true | Should -BeTrue } }" | Set-Content (Join-Path $script:run 'C.Tests.ps1')
        $script:target = Join-Path $TestDrive 'elsewhere/clobbered.xml'
        @{ Output = @{ TestResult = @{ Path = $script:target } } } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:parent 'maester-config.json')
        $script:relative = Join-Path $script:run 'out.xml'
        $script:log = Join-Path $TestDrive 'log.txt'
        $lines = @(
            "Import-Module '$script:manifest' -WarningAction SilentlyContinue"
            "Set-Location '$script:run'"
            "`$null = Invoke-Maester -Path '$script:run' -SkipBuiltIn -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputFolder '$(Join-Path $TestDrive 'reports')' 3>&1 | Out-File '$script:log'"
        )
        $null = pwsh -NoProfile -NonInteractive -Command ($lines -join [Environment]::NewLine) 2>&1
    }

    It 'Does not write the XML file outside the current folder' {
        $script:target | Should -Not -Exist
    }

    It 'Warns about the ignored path and about a parent-folder config that sets Output' {
        $log = Get-Content -LiteralPath $script:log -Raw
        $log | Should -Match 'outside the current folder'
        $log | Should -Match 'is outside .* and sets Output'
    }
}
