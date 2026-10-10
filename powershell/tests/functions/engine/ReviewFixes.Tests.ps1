BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force -WarningAction SilentlyContinue

    function New-TestFile {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([string] $Folder, [string] $Id, [string] $Body, [string] $Extra = '')
        $null = New-Item -ItemType Directory -Path $Folder -Force
        $name = 'Test-' + ($Id -replace '[^A-Za-z0-9]', '')
        @"
function $name {
    [MaesterTest(Id = '$Id', Title = 'Title of $Id', Severity = 'High'$Extra)]
    [CmdletBinding()]
    param()
    $Body
}
"@ | Set-Content (Join-Path $Folder "Test.$Id.ps1")
        "Description of $Id.`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $Folder "Test.$Id.md")
        Join-Path $Folder "Test.$Id.ps1"
    }
}

Describe 'Code review fixes' {
    It 'Reports a binding error inside a command the test calls as TestError, not InvalidConfiguration' {
        $file = New-TestFile -Folder (Join-Path $TestDrive 'binding') -Id 'CONTOSO.10' -Body @'
    function Get-Thing { param([Parameter(Mandatory)] [string] $Name) $Name }
    Get-Thing -Name $null
    $true
'@
        $row = Invoke-MtTest -Path $file
        $row.Result | Should -Be 'Error'
        $row.ReasonCode | Should -Be 'TestError'
    }

    It 'Does not carry a skip from an earlier Invoke-MtTest call into the next one' {
        $folder = Join-Path $TestDrive 'stale'
        $flag = Join-Path $TestDrive 'skip.flag'
        $file = New-TestFile -Folder $folder -Id 'CONTOSO.11' -Body @"
    if (Test-Path '$flag') { Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not now'; return `$null }
    `$true
"@
        'x' | Set-Content $flag
        (Invoke-MtTest -Path $file).Result | Should -Be 'Skipped'
        Remove-Item $flag
        $row = Invoke-MtTest -Path $file
        $row.Result | Should -Be 'Passed'
        $row.ReasonCode | Should -BeNullOrEmpty
    }

    It 'Keeps the identity of a test that runs another test with Invoke-MtTest' {
        $folder = Join-Path $TestDrive 'nested'
        $inner = New-TestFile -Folder (Join-Path $folder 'inner') -Id 'CONTOSO.13' -Body '$true'
        $outer = New-TestFile -Folder $folder -Id 'CONTOSO.12' -Body @"
    `$null = Invoke-MtTest -Path '$inner'
    Add-MtTestResultDetail -Result 'Outer result after the nested run'
    `$true
"@
        $row = Invoke-MtTest -Path $outer
        $row.Result | Should -Be 'Passed'
        $row.ResultDetail.TestResult | Should -BeLike '*Outer result after the nested run*'
        [Maester.Engine.MtSession]::GetCurrentTest() | Should -BeNullOrEmpty
    }

    It 'Turns off the run timeout for a test whose TimeoutSeconds is 0' {
        $file = New-TestFile -Folder (Join-Path $TestDrive 'timeout') -Id 'CONTOSO.14' -Body 'Start-Sleep -Milliseconds 1500; $true'
        $config = @{ Execution = @{ TestTimeoutSeconds = 1 }; TestSettings = @(@{ Id = 'CONTOSO.14'; TimeoutSeconds = 0 }) }
        (Invoke-MtTest -Path $file -Config $config).Result | Should -Be 'Passed'
    }

    It 'Writes a relative XML path under the PowerShell location' {
        $folder = Join-Path $TestDrive 'xml'
        $null = New-Item -ItemType Directory -Path $folder -Force
        $results = [pscustomobject]@{ ExecutedAt = (Get-Date).ToString('o'); Tests = @([pscustomobject]@{ Id = 'X.1'; Name = 'X.1: x'; Block = 'B'; Result = 'Passed'; Duration = '00:00:01'; ResultDetail = $null }) }
        Push-Location $folder
        try { InModuleScope Maester -Parameters @{ R = $results } { Export-MtTestResultXml -MaesterResults $R -Path 'rel/out.xml' -Format NUnitXml } } finally { Pop-Location }
        Join-Path $folder 'rel/out.xml' | Should -Exist
    }

    It 'Does not change the caller''s PesterConfiguration object' {
        $original = New-PesterConfiguration
        $original.Filter.Tag = 'CA'
        $copy = InModuleScope Maester -Parameters @{ C = $original } { New-MtPesterConfiguration -Configuration $C }
        $copy.Filter.ExcludeTag = 'Preview'
        $copy.TestResult.Enabled = $false
        [object]::ReferenceEquals($copy, $original) | Should -BeFalse
        $copy.Filter.Tag.Value | Should -Be @('CA')
        @($original.Filter.ExcludeTag.Value) | Should -HaveCount 0
    }

    It 'Merges a family run in one partition over the NotRun parent row of another' {
        $a = [pscustomobject]@{ Result = 'Passed'; CatalogVersion = '3.0.0'; TotalDuration = '00:00:01'; ExecutedAt = '2026-10-01'; TenantId = 't'; Blocks = @(); EndOfJson = 'EndOfJson'
            Tests = @(
                [pscustomobject]@{ Index = 0; Id = 'MT.X.a'; Name = 'a'; Result = 'Passed'; Block = 'B'; ParentId = 'MT.X' }
                [pscustomobject]@{ Index = 0; Id = 'MT.X.b'; Name = 'b'; Result = 'Passed'; Block = 'B'; ParentId = 'MT.X' })
        }
        $b = [pscustomobject]@{ Result = 'Passed'; CatalogVersion = '3.0.0'; TotalDuration = '00:00:01'; ExecutedAt = '2026-10-01'; TenantId = 't'; Blocks = @(); EndOfJson = 'EndOfJson'
            Tests = @([pscustomobject]@{ Index = 0; Id = 'MT.X'; Name = 'x'; Result = 'NotRun'; Block = 'B'; ParentId = $null })
        }
        $m = Merge-MtMaesterResult -MaesterResults $a, $b -SameRun
        $m.Tests.Id | Sort-Object | Should -Be @('MT.X.a', 'MT.X.b')
        $m.NotRunCount | Should -Be 0
    }
}

Describe 'Skip text for a test that returns no result' {
    It 'Uses the suite''s NoResultReason' {
        $folder = Join-Path $TestDrive 'noresult'
        $file = New-TestFile -Folder $folder -Id 'CONTOSO.20' -Body 'return $null'
        @{ Id = 'CONTOSO'; Source = 'Custom'; NoResultReason = 'Directory data could not be retrieved' } | ConvertTo-Json | Set-Content (Join-Path $folder 'suite.json')
        $row = Invoke-MtTest -Path $file
        $row.Result | Should -Be 'Skipped'
        $row.ReasonDetail | Should -Be 'Directory data could not be retrieved'
        $row.ResultDetail.TestResult | Should -Be 'Skipped. Directory data could not be retrieved'
    }

    It 'Falls back to the generic text without one' {
        $file = New-TestFile -Folder (Join-Path $TestDrive 'noresult-generic') -Id 'CONTOSO.21' -Body 'return $null'
        (Invoke-MtTest -Path $file).ReasonDetail | Should -Be 'The test returned no result.'
    }

    It 'Gives the Active Directory tests the 2.x wording' {
        (Get-MtTest -Id 'AD-TRUST-03').NoResultReason | Should -Be 'Active Directory data could not be retrieved'
    }
}

Describe 'Update-MaesterTests on a 2.x config copy' {
    It 'Keeps only rows that differ from the built-in severities' {
        $folder = Join-Path $TestDrive 'update'
        $null = New-Item -ItemType Directory -Path $folder -Force
        $catalog = @(InModuleScope Maester { Get-MtTestCatalog } | Select-Object -First 320)
        $rows = @($catalog | ForEach-Object { [ordered]@{ Id = $_.Id; Title = $_.Title; Severity = $_.Severity } })
        $rows[0].Severity = if ($rows[0].Severity -eq 'Low') { 'High' } else { 'Low' }
        $rows += [ordered]@{ Id = 'MT.9999'; Title = 'Removed test'; Severity = 'High' }
        @{ ModuleVersion = '2.2.0'; TestSettings = $rows } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $folder 'maester-config.json')
        $null = Update-MaesterTests -Path $folder -Confirm:$false -WarningAction SilentlyContinue 6>$null
        $kept = @((Get-Content (Join-Path $folder 'maester-config.json') -Raw | ConvertFrom-Json).TestSettings)
        $kept | Should -HaveCount 1
        $kept[0].Id | Should -Be $catalog[0].Id
    }
}

Describe 'Engine review fixes' {
    Context '-Path that is one test file' {
        It 'Looks for the config files in the folder of the file' {
            $file = New-TestFile -Folder (Join-Path $TestDrive 'onefile') -Id 'CONTOSO.20' -Body '$true' -Extra ", Service = 'None'"
            $source = InModuleScope Maester -Parameters @{ File = $file } { Resolve-MtTestSource -Path $File -SkipBuiltIn }
            $source.Error | Should -BeNullOrEmpty
            $source.ConfigSearchPath | Should -Be (Split-Path (Resolve-Path $file).Path -Parent)
            # A file is never read as the config: only real config files of its folder are found.
            InModuleScope Maester -Parameters @{ File = $file } { @(Find-MtConfigFile -Path $File) } | Should -HaveCount 0
        }

        It 'Runs the test and applies the maester-config.json beside it' {
            $folder = Join-Path $TestDrive 'onefile-run'
            $file = New-TestFile -Folder $folder -Id 'CONTOSO.21' -Extra ", Service = 'None'" -Body @'
    Add-MtTestResultDetail -Result 'ok'
    $true
'@
            '{ "TestSettings": [ { "Id": "CONTOSO.21", "Severity": "Critical" } ] }' | Set-Content (Join-Path $folder 'maester-config.json')
            $result = Invoke-Maester -Path $file -SkipBuiltIn -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck `
                -OutputFolder (Join-Path $TestDrive 'onefile-out') -PassThru 6>$null
            $result.TotalCount | Should -Be 1
            $result.Tests[0].Id | Should -Be 'CONTOSO.21'
            $result.Tests[0].Result | Should -Be 'Passed'
            $result.Tests[0].Severity | Should -Be 'Critical'
        }
    }

    Context 'Metadata that cannot be read' {
        It 'Reports a parameter validation that is not a constant as one invalid test, also under ErrorActionPreference Stop' {
            $folder = Join-Path $TestDrive 'badrange'
            $null = New-Item -ItemType Directory -Path $folder -Force
            @'
function Test-ContosoBadRange {
    [MaesterTest(Id = 'CONTOSO.30', Title = 'Bad range', Severity = 'High', Service = 'None')]
    [CmdletBinding()]
    param(
        [ValidateRange(1, [int]::MaxValue)] [int] $Days = 5
    )
    $true
}
'@ | Set-Content (Join-Path $folder 'Test.CONTOSO.30.ps1')
            'Description.' | Set-Content (Join-Path $folder 'Test.CONTOSO.30.md')
            New-TestFile -Folder $folder -Id 'CONTOSO.31' -Body '$true' -Extra ", Service = 'None'" | Out-Null

            $tests = & { $ErrorActionPreference = 'Stop'; @(Get-MtTest -Path $folder) }
            $bad = $tests | Where-Object Id -EQ 'CONTOSO.30'
            $bad.IsValid | Should -BeFalse
            $bad.Errors.Code | Should -Be 'InvalidMetadata'
            $bad.Errors.Message | Should -Match 'ValidateRange'
            # The file next to it is not affected.
            ($tests | Where-Object Id -EQ 'CONTOSO.31').IsValid | Should -BeTrue
        }

        It 'Reads RequiresMaester <Value> in suite.json as <Expected>' -ForEach @(
            @{ Value = '3'; Expected = 'valid' }
            @{ Value = '3.0'; Expected = 'valid' }
            @{ Value = '99'; Expected = 'RequiresNewerMaester' }
            @{ Value = 'soon'; Expected = 'InvalidMetadata' }
        ) {
            $folder = Join-Path $TestDrive "suite-$Value"
            New-TestFile -Folder $folder -Id 'CONTOSO.40' -Body '$true' -Extra ", Service = 'None'" | Out-Null
            @{ Id = 'CONTOSO'; Source = 'Custom'; RequiresMaester = $Value } | ConvertTo-Json | Set-Content (Join-Path $folder 'suite.json')
            $test = & { $ErrorActionPreference = 'Stop'; Get-MtTest -Path $folder }
            if ($Expected -eq 'valid') {
                $test.IsValid | Should -BeTrue -Because ($test.Errors.Message -join '; ')
            } else {
                $test.IsValid | Should -BeFalse
                $inventory = InModuleScope Maester -Parameters @{ Folder = $folder } { @(Get-MtNativeTestInventory -Path $Folder) }
                $inventory[0].Errors.Code | Should -Contain $Expected
            }
        }
    }
}
