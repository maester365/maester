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

    Context 'Console output that fails' {
        It 'Keeps the result of a test when writing its console line fails' {
            $file = New-TestFile -Folder (Join-Path $TestDrive 'console-fails') -Id 'CONTOSO.70' -Extra ", Service = 'None'" -Body @'
    Add-MtTestResultDetail -Result 'ok'
    $true
'@
            Mock -ModuleName Maester Write-MtNativeResultLine { throw 'the console is gone' }
            $result = Invoke-Maester -Path $file -SkipBuiltIn -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck `
                -Verbosity Normal -OutputFolder (Join-Path $TestDrive 'console-fails-out') -PassThru 6>$null
            Should -Invoke -ModuleName Maester Write-MtNativeResultLine -Times 1
            $result.TotalCount | Should -Be 1
            $result.Tests[0].Result | Should -Be 'Passed'
        }
    }

    Context 'Family instances' {
        BeforeAll {
            function New-FamilyFile {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
                param([string] $Folder, [string] $Id, [string] $Source)
                $null = New-Item -ItemType Directory -Path $Folder -Force
                $name = $Id -replace '[^A-Za-z0-9]', ''
                @"
function Get-Instance$name {
    [CmdletBinding()]
    param()
    $Source
}

function Test-Family$name {
    [MaesterTest(Id = '$Id', Title = 'Attribute title', Severity = 'Low', Service = 'None', InstanceSource = 'Get-Instance$name')]
    [CmdletBinding()]
    param(
        # The instance, supplied by the engine.
        `$Instance
    )
    `$true
}
"@ | Set-Content (Join-Path $Folder "Test.$Id.ps1")
                "Description of $Id.`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $Folder "Test.$Id.md")
                Join-Path $Folder "Test.$Id.ps1"
            }
        }

        It 'Reads Title, Severity and Tag of an instance returned as a <Shape>' -ForEach @(
            @{ Shape = 'hashtable'; Source = "@{ Id = 'a'; Title = 'Instance title'; Severity = 'Critical'; Tag = 'FromInstance' }" }
            @{ Shape = 'object'; Source = "[pscustomobject]@{ Id = 'a'; Title = 'Instance title'; Severity = 'Critical'; Tag = 'FromInstance' }" }
        ) {
            $file = New-FamilyFile -Folder (Join-Path $TestDrive "family-$Shape") -Id 'CONTOSO.50' -Source $Source
            $row = Invoke-MtTest -Path $file
            $row.Id | Should -Be 'CONTOSO.50.a'
            $row.Title | Should -Be 'Instance title'
            $row.Severity | Should -Be 'Critical'
            $row.Tag | Should -Contain 'FromInstance'
        }

        It 'Rejects an instance ID that ends in a newline' {
            $file = New-FamilyFile -Folder (Join-Path $TestDrive 'family-newline') -Id 'CONTOSO.51' -Source '[pscustomobject]@{ Id = "c`n" }'
            $row = Invoke-MtTest -Path $file
            $row.Result | Should -Be 'Error'
            $row.ReasonCode | Should -Be 'InvalidInstanceId'
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

Describe 'Maintainer review fixes' {
    BeforeAll {
        function New-ReviewTest {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([string] $Folder, [string] $Id, [string] $Extra = '', [string] $Body = '$true')
            New-TestFile -Folder $Folder -Id $Id -Body $Body -Extra ", Service = 'None'$Extra" | Out-Null
        }

        function Invoke-ReviewRun {
            param([string] $Path, [hashtable] $Config, [switch] $WithBuiltIn)
            $arguments = @{
                Path = $Path; SkipGraphConnect = $true; NonInteractive = $true; DisableTelemetry = $true; SkipVersionCheck = $true
                OutputFolder = (Join-Path $TestDrive "out-$([guid]::NewGuid().ToString('N'))"); PassThru = $true
            }
            if (-not $WithBuiltIn) { $arguments.SkipBuiltIn = $true }
            if ($Config) { $arguments.Config = $Config }
            Invoke-Maester @arguments 6>$null
        }

        function New-FamilyTest {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([string] $Folder, [string] $Id, [string] $Source, [string] $Param = '', [string] $Body = '$true')
            $null = New-Item -ItemType Directory -Path $Folder -Force
            $name = $Id -replace '[^A-Za-z0-9]', ''
            @"
function Get-Instance$name {
    [CmdletBinding()]
    param()
    $Source
}

function Test-Family$name {
    [MaesterTest(Id = '$Id', Title = 'Family', Severity = 'Low', Service = 'None', InstanceSource = 'Get-Instance$name')]
    [CmdletBinding()]
    param(
        # The instance, supplied by the engine.
        `$Instance$Param
    )
    $Body
}
"@ | Set-Content (Join-Path $Folder "Test.$Id.ps1")
            "Description of $Id.`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $Folder "Test.$Id.md")
        }
    }

    Context 'The tenant config file decides the selection' {
        BeforeAll {
            $script:tenantId = '11111111-2222-3333-4444-555555555555'
            Mock -ModuleName Maester Get-MtConfigTenantId { '11111111-2222-3333-4444-555555555555' }

            function New-TenantFolder {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
                param([string] $Name, [hashtable] $TenantConfig)
                $folder = Join-Path $TestDrive $Name
                New-ReviewTest -Folder $folder -Id 'REVIEW.1'
                New-ReviewTest -Folder $folder -Id 'REVIEW.2'
                New-ReviewTest -Folder $folder -Id 'REVIEW.3' -Extra ', Preview'
                '{}' | Set-Content (Join-Path $folder 'maester-config.json')
                $TenantConfig | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $folder "maester-config.$script:tenantId.json")
                $folder
            }
        }

        It 'Applies an allow list from the tenant file to native tests' {
            $folder = New-TenantFolder -Name 'tenant-allow' -TenantConfig @{
                Selection    = @{ DefaultAction = 'Skip'; TestId = @('REVIEW.1') }
                TestSettings = @(@{ Id = 'REVIEW.1'; Enabled = $true })
            }
            $r = Invoke-ReviewRun -Path $folder
            ($r.Tests | Where-Object Id -EQ 'REVIEW.1').Result | Should -Be 'Passed'
            ($r.Tests | Where-Object Id -EQ 'REVIEW.2').Result | Should -Be 'NotRun'
            $r.MaesterConfig.Selection.DefaultAction | Should -Be 'Skip'
        }

        It 'Applies ExcludeTestId, a disabled row and IncludePreview from the tenant file' {
            $folder = New-TenantFolder -Name 'tenant-exclude' -TenantConfig @{
                Selection    = @{ ExcludeTestId = @('REVIEW.1'); IncludePreview = $true }
                TestSettings = @(@{ Id = 'REVIEW.2'; Enabled = $false; Reason = 'Not for this tenant' })
            }
            $r = Invoke-ReviewRun -Path $folder
            ($r.Tests | Where-Object Id -EQ 'REVIEW.1').ReasonCode | Should -Be 'ExcludedById'
            $disabled = $r.Tests | Where-Object Id -EQ 'REVIEW.2'
            $disabled.ReasonCode | Should -Be 'DisabledByConfig'
            $disabled.ReasonDetail | Should -Be 'Not for this tenant'
            ($r.Tests | Where-Object Id -EQ 'REVIEW.3').Result | Should -Be 'Passed' -Because 'the tenant file includes Preview tests'
        }

        It 'Leaves Preview tests out when the tenant file does not include them' {
            $folder = New-TenantFolder -Name 'tenant-nopreview' -TenantConfig @{ Selection = @{ ExcludeTestId = @('REVIEW.1') } }
            $r = Invoke-ReviewRun -Path $folder
            ($r.Tests | Where-Object Id -EQ 'REVIEW.3').Result | Should -Be 'NotRun'
        }

        It 'Leaves the built-in tests out when the tenant file sets Selection.BuiltIn to None' {
            $folder = New-TenantFolder -Name 'tenant-builtin' -TenantConfig @{ Selection = @{ BuiltIn = 'None' } }
            $r = Invoke-ReviewRun -Path $folder -WithBuiltIn
            $r.Selection.BuiltIn | Should -Be 'None'
            @($r.Tests).Count | Should -Be 3
        }

        It 'Stops the run for an unknown ID when the tenant file sets OnUnknownId to Error' {
            $folder = New-TenantFolder -Name 'tenant-unknown' -TenantConfig @{ Selection = @{ TestId = @('REVIEW.1', 'NOPE.1'); OnUnknownId = 'Error' } }
            $failures = $null
            $r = Invoke-Maester -Path $folder -SkipBuiltIn -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck `
                -OutputFolder (Join-Path $TestDrive 'out-unknown') -PassThru -ErrorVariable failures -ErrorAction SilentlyContinue 6>$null
            $r | Should -BeNullOrEmpty
            ($failures | ForEach-Object { "$_" }) -join ' ' | Should -Match 'NOPE\.1'
        }

        It 'Is not read when -Config is given' {
            $folder = New-TenantFolder -Name 'tenant-hermetic' -TenantConfig @{ Selection = @{ ExcludeTestId = @('REVIEW.1') } }
            $r = Invoke-ReviewRun -Path $folder -Config @{}
            ($r.Tests | Where-Object Id -EQ 'REVIEW.1').Result | Should -Be 'Passed'
        }
    }

    Context 'A single test file and the suite.json beside it' {
        It 'Applies the suite tags and the required Maester version when -Path is the file' {
            $folder = Join-Path $TestDrive 'suite-onefile'
            New-ReviewTest -Folder $folder -Id 'REVIEW.10'
            @{ Id = 'CONTOSO'; Source = 'Contoso'; Tags = @('ContosoSuite') } | ConvertTo-Json | Set-Content (Join-Path $folder 'suite.json')
            $file = Join-Path $folder 'Test.REVIEW.10.ps1'
            $row = (Invoke-ReviewRun -Path $file).Tests[0]
            $row.Result | Should -Be 'Passed'
            $row.Suite | Should -Be 'CONTOSO'
            $row.Tag | Should -Contain 'ContosoSuite'

            @{ Id = 'CONTOSO'; Source = 'Contoso'; RequiresMaester = '99.0' } | ConvertTo-Json | Set-Content (Join-Path $folder 'suite.json')
            $byFile = (Invoke-ReviewRun -Path $file).Tests[0]
            $byFolder = (Invoke-ReviewRun -Path $folder).Tests[0]
            $byFile.Result | Should -Be 'Error'
            $byFile.ReasonCode | Should -Be 'RequiresNewerMaester'
            $byFile.ReasonCode | Should -Be $byFolder.ReasonCode
        }
    }

    Context 'Config rows for one instance of a family' {
        BeforeAll {
            $script:familyFolder = Join-Path $TestDrive 'family-parameters'
            New-FamilyTest -Folder $script:familyFolder -Id 'REVIEW.FAMILY' -Source "[pscustomobject]@{ Id = 'a' }, [pscustomobject]@{ Id = 'b' }" `
                -Param ",`n        # What the test compares with.`n        [int] `$Threshold = 1,`n        # Text.`n        [string] `$Label = 'none'" `
                -Body 'Add-MtTestResultDetail -Result "Threshold $Threshold, label $Label"; $Threshold -eq 2'
        }

        It 'Binds the parameters of an instance row for that instance only' {
            $r = Invoke-ReviewRun -Path $script:familyFolder -Config @{ TestSettings = @(@{ Id = 'REVIEW.FAMILY.a'; Parameters = @{ Threshold = 2 } }) }
            $a = $r.Tests | Where-Object Id -EQ 'REVIEW.FAMILY.a'
            $b = $r.Tests | Where-Object Id -EQ 'REVIEW.FAMILY.b'
            $a.Result | Should -Be 'Passed'
            $b.Result | Should -Be 'Failed'
            ($a.Parameters | Where-Object Name -EQ 'Threshold').Value | Should -Be 2
            ($a.Parameters | Where-Object Name -EQ 'Threshold').Source | Should -Be 'Config'
            ($b.Parameters | Where-Object Name -EQ 'Threshold').Source | Should -Be 'Default'
        }

        It 'Keeps the parameters of the family row that the instance row does not name' {
            $r = Invoke-ReviewRun -Path $script:familyFolder -Config @{ TestSettings = @(
                    @{ Id = 'REVIEW.FAMILY'; Parameters = @{ Label = 'family'; Threshold = 2 } }
                    @{ Id = 'REVIEW.FAMILY.a'; Parameters = @{ Threshold = 5 } }) }
            $a = $r.Tests | Where-Object Id -EQ 'REVIEW.FAMILY.a'
            $b = $r.Tests | Where-Object Id -EQ 'REVIEW.FAMILY.b'
            ($a.Parameters | Where-Object Name -EQ 'Threshold').Value | Should -Be 5
            ($a.Parameters | Where-Object Name -EQ 'Label').Value | Should -Be 'family'
            $a.Result | Should -Be 'Failed'
            $b.Result | Should -Be 'Passed'
        }

        It 'Reports an invalid parameter of an instance row on that instance and still runs the others' {
            $r = Invoke-ReviewRun -Path $script:familyFolder -Config @{ TestSettings = @(@{ Id = 'REVIEW.FAMILY.a'; Parameters = @{ Threshold = 'many' } }) }
            $a = $r.Tests | Where-Object Id -EQ 'REVIEW.FAMILY.a'
            $a.Result | Should -Be 'Error'
            $a.ReasonCode | Should -Be 'InvalidConfiguration'
            ($r.Tests | Where-Object Id -EQ 'REVIEW.FAMILY.b').Result | Should -Be 'Failed'
        }

        It 'Uses the timeout of an instance row, and 0 turns the timeout off for that instance' {
            $folder = Join-Path $TestDrive 'family-timeout'
            New-FamilyTest -Folder $folder -Id 'REVIEW.SLOW' -Source "[pscustomobject]@{ Id = 'a' }, [pscustomobject]@{ Id = 'b' }" `
                -Body 'if ($Instance.Id -eq ''a'') { Start-Sleep -Seconds 3 }; $true'
            # Instance a has its own one-second timeout; b has none.
            $r = Invoke-ReviewRun -Path $folder -Config @{ TestSettings = @(@{ Id = 'REVIEW.SLOW.a'; TimeoutSeconds = 1 }) }
            ($r.Tests | Where-Object Id -EQ 'REVIEW.SLOW.a').ReasonCode | Should -Be 'Timeout'
            ($r.Tests | Where-Object Id -EQ 'REVIEW.SLOW.b').Result | Should -Be 'Passed'
            # The run has a one-second timeout; instance a turns it off for itself.
            $r = Invoke-ReviewRun -Path $folder -Config @{ Execution = @{ TestTimeoutSeconds = 1 }; TestSettings = @(@{ Id = 'REVIEW.SLOW.a'; TimeoutSeconds = 0 }) }
            ($r.Tests | Where-Object Id -EQ 'REVIEW.SLOW.a').Result | Should -Be 'Passed'
            ($r.Tests | Where-Object Id -EQ 'REVIEW.SLOW.b').Result | Should -Be 'Passed'
        }
    }

    Context 'The instance source of a family' {
        It 'Is stopped at the timeout, reported on the family, and later tests still run' {
            $folder = Join-Path $TestDrive 'family-source-timeout'
            New-FamilyTest -Folder $folder -Id 'REVIEW.HANG' -Source "Start-Sleep -Seconds 20; [pscustomobject]@{ Id = 'a' }"
            New-ReviewTest -Folder $folder -Id 'REVIEW.LATER'
            $clock = [System.Diagnostics.Stopwatch]::StartNew()
            $r = Invoke-ReviewRun -Path $folder -Config @{ Execution = @{ TestTimeoutSeconds = 1 } }
            $clock.Elapsed.TotalSeconds | Should -BeLessThan 15
            $family = $r.Tests | Where-Object Id -EQ 'REVIEW.HANG'
            $family.Result | Should -Be 'Error'
            $family.ReasonCode | Should -Be 'InstanceSourceFailed'
            $family.ReasonDetail | Should -Match 'did not finish within 1 seconds'
            ($r.Tests | Where-Object Id -EQ 'REVIEW.LATER').Result | Should -Be 'Passed'
        }

        It 'Contains exit in a source instead of ending the session' {
            $folder = Join-Path $TestDrive 'family-source-exit'
            New-FamilyTest -Folder $folder -Id 'REVIEW.EXIT' -Source 'exit 3'
            New-ReviewTest -Folder $folder -Id 'REVIEW.AFTER'
            $r = Invoke-ReviewRun -Path $folder
            ($r.Tests | Where-Object Id -EQ 'REVIEW.EXIT').ReasonCode | Should -Be 'InstanceSourceFailed'
            ($r.Tests | Where-Object Id -EQ 'REVIEW.AFTER').Result | Should -Be 'Passed'
        }
    }
}
