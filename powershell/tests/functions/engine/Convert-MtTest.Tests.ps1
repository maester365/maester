BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force

    function Invoke-Convert {
        param([string] $Path, [switch] $Force)
        InModuleScope Maester -Parameters @{ P = $Path; F = [bool]$Force } { Convert-MtTest -Path $P -Force:$F -Confirm:$false }
    }
}

Describe 'Convert-MtTest' {
    BeforeEach {
        $script:folder = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        $null = New-Item -ItemType Directory -Path $script:folder
    }

    It 'Converts the split-file pattern and removes the connection guard and outer try/catch' {
        @'
function Test-ContosoBreakGlass {
    <#
    .SYNOPSIS
    Checks the break-glass accounts.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        $users = Invoke-MtGraphRequest -RelativeUri 'users'
        return ($users.Count -gt 0)
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
'@ | Set-Content (Join-Path $script:folder 'Test-ContosoBreakGlass.ps1')
        "# Break glass`n`nCheck them." | Set-Content (Join-Path $script:folder 'Test-ContosoBreakGlass.md')
        @'
Describe "Contoso" -Tag "Contoso", "Severity:High" {
    It "CONTOSO.1001: Break-glass accounts exist" -Tag "BreakGlass" {
        Test-ContosoBreakGlass | Should -Be $true -Because "they are needed"
    }
}
'@ | Set-Content (Join-Path $script:folder 'Contoso.Tests.ps1')

        $report = @(Invoke-Convert -Path $script:folder)
        $report | Should -HaveCount 1
        $report[0].Id | Should -Be 'CONTOSO.1001'
        $report[0].Status | Should -Be 'Converted'

        $t = InModuleScope Maester -Parameters @{ F = (Join-Path $script:folder 'Test.CONTOSO.1001.ps1') } { Read-MtNativeTest -Path $F }
        $t.Errors | Should -HaveCount 0
        $t.FunctionName | Should -Be 'Test-ContosoBreakGlass'
        $t.Title | Should -Be 'Break-glass accounts exist'
        $t.Severity | Should -Be 'High'
        $t.Category | Should -Be 'Contoso'
        $t.Service | Should -Be @('Graph')
        $t.Tag | Should -Contain 'BreakGlass'
        $code = Get-Content (Join-Path $script:folder 'Test.CONTOSO.1001.ps1') -Raw
        $code | Should -Not -Match 'Test-MtConnection'
        $code | Should -Not -Match '\btry\b'
        $code | Should -Match 'return \(\$users.Count -gt 0\)'
        Get-Content (Join-Path $script:folder 'Test.CONTOSO.1001.md') -Raw | Should -Match '<!--- Results --->'
    }

    It 'Converts inline logic and flags assertions it cannot rewrite' {
        @'
Describe "Custom" {
    It "CT0001: Inline check" {
        $value = 1 + 1
        ($value -eq 2) | Should -Be $true
    }
    It "CT0002: Other assertion" {
        $value = 'a'
        $value | Should -Match 'a'
    }
}
'@ | Set-Content (Join-Path $script:folder 'Custom.Tests.ps1')

        $report = @(Invoke-Convert -Path $script:folder)
        ($report | Where-Object Id -EQ 'CT0001').Status | Should -Be 'Converted'
        ($report | Where-Object Id -EQ 'CT0001').Notes | Should -Match 'prefix'
        ($report | Where-Object Id -EQ 'CT0002').Status | Should -Be 'NeedsReview'
        Get-Content (Join-Path $script:folder 'Test.CT0001.ps1') -Raw | Should -Match 'return \(\(\$value -eq 2\)\)'
    }

    It 'Skips run-time names and invalid IDs, and keeps existing files without -Force' {
        @'
Describe "Custom" {
    It "CONTOSO.<_>: Family" -ForEach @('a') { $true | Should -Be $true }
    It "no id here" { $true | Should -Be $true }
    It "CONTOSO.2: Exists" { $true | Should -Be $true }
}
'@ | Set-Content (Join-Path $script:folder 'Custom.Tests.ps1')
        'existing' | Set-Content (Join-Path $script:folder 'Test.CONTOSO.2.ps1')

        $report = @(Invoke-Convert -Path $script:folder)
        $report | Should -HaveCount 3
        $report.Status | Should -Be @('Skipped', 'Skipped', 'Skipped')
        Get-Content (Join-Path $script:folder 'Test.CONTOSO.2.ps1') -Raw | Should -Match 'existing'

        $report = @(Invoke-Convert -Path $script:folder -Force)
        ($report | Where-Object Id -EQ 'CONTOSO.2').Status | Should -Be 'Converted'
    }

    It 'Writes nothing with -WhatIf' {
        'Describe "C" { It "CONTOSO.3: X" { $true | Should -Be $true } }' | Set-Content (Join-Path $script:folder 'C.Tests.ps1')
        $null = InModuleScope Maester -Parameters @{ P = $script:folder } { Convert-MtTest -Path $P -WhatIf }
        Join-Path $script:folder 'Test.CONTOSO.3.ps1' | Should -Not -Exist
    }

    It 'Runs the converted native test instead of the Pester test with the same ID' {
        'Describe "C" { It "CONTOSO.4: Inline" { $true | Should -Be $true } }' | Set-Content (Join-Path $script:folder 'C.Tests.ps1')
        $null = Invoke-Convert -Path $script:folder
        $out = Join-Path $TestDrive 'native-wins.json'
        $manifest = (Resolve-Path "$PSScriptRoot/../../../Maester.psd1").Path
        $command = "Import-Module '$manifest' -WarningAction SilentlyContinue; `$null = Invoke-Maester -Path '$($script:folder)' -SkipBuiltIn -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputJsonFile '$out' -WarningAction SilentlyContinue"
        $null = pwsh -NoProfile -NonInteractive -Command $command 2>&1
        $result = Get-Content $out -Raw | ConvertFrom-Json
        $rows = @($result.Tests | Where-Object Id -EQ 'CONTOSO.4')
        $rows | Should -HaveCount 1
        $rows[0].Format | Should -Be 'Native'
        $rows[0].Result | Should -Be 'Passed'
        ($result.Selection.Superseded | Where-Object Id -EQ 'CONTOSO.4').MatchedBy | Should -Be 'NativeTest'
    }
}
