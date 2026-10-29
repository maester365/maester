BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    function New-ResultFile {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([string]$Folder, [string]$Name, [datetime]$ExecutedAt, [hashtable]$States, [hashtable]$Extra = @{})
        $report = [ordered]@{
            Account = 'a'; Blocks = @(); CurrentVersion = '1'; ExecutedAt = $ExecutedAt.ToString('o'); ErrorCount = 0; FailedCount = 0
            InvestigateCount = 0; LatestVersion = '1'; NotRunCount = 0; PassedCount = 0; Result = 'Passed'; SkippedCount = 0
            TenantId = 'tenant-1'; TenantName = 'Contoso'; TotalCount = $States.Count
            Tests = @($States.GetEnumerator() | ForEach-Object { [ordered]@{ Name = $_.Key; Result = $_.Value } })
        }
        foreach ($key in $Extra.Keys) { $report[$key] = $Extra[$key] }
        $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Folder $Name)
    }
}

Describe 'Compare-MtTestResult' -Tag 'Unit' {
    BeforeEach {
        $script:folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "mt-compare-$([guid]::NewGuid())")
    }

    AfterEach {
        Remove-Item -LiteralPath $script:folder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'compares result files that carry more properties than the required ones' {
        $extra = @{ TotalDuration = '00:01:00'; SystemInfo = @{ OS = 'Linux' }; SchemaVersion = '2' }
        New-ResultFile -Folder $script:folder -Name 'TestResults-1.json' -ExecutedAt '2026-01-01' -States @{ T1 = 'Passed'; T2 = 'Passed' } -Extra $extra
        New-ResultFile -Folder $script:folder -Name 'TestResults-2.json' -ExecutedAt '2026-02-01' -States @{ T1 = 'Failed'; T2 = 'Passed' } -Extra $extra

        $delta = @(Compare-MtTestResult -BaseDir $script:folder)

        $delta.Name | Should -Contain 'T1'
        ($delta | Where-Object Name -eq 'T1' | Select-Object -First 1).PriorState | Should -Be 'Passed'
    }

    It 'still compares files that have exactly the required properties' {
        New-ResultFile -Folder $script:folder -Name 'TestResults-1.json' -ExecutedAt '2026-01-01' -States @{ T1 = 'Passed' }
        New-ResultFile -Folder $script:folder -Name 'TestResults-2.json' -ExecutedAt '2026-02-01' -States @{ T1 = 'Failed' }

        @(Compare-MtTestResult -BaseDir $script:folder).Name | Should -Contain 'T1'
    }

    It 'skips a file that lacks a required property' {
        New-ResultFile -Folder $script:folder -Name 'TestResults-1.json' -ExecutedAt '2026-01-01' -States @{ T1 = 'Passed' }
        $broken = Get-Content (Join-Path $script:folder 'TestResults-1.json') -Raw | ConvertFrom-Json
        $broken.PSObject.Properties.Remove('TenantId')
        $broken | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:folder 'TestResults-2.json')

        $warnings = @()
        @(Compare-MtTestResult -BaseDir $script:folder -WarningAction SilentlyContinue -WarningVariable warnings) | Should -BeNullOrEmpty

        ($warnings -join "`n") | Should -Match 'TenantId'
        ($warnings -join "`n") | Should -Match 'TestResults-2\.json'
    }
}
