# Benchmarks and framework files (docs/proposals/maester-3.0-test-attributes.md, section 6): the Frameworks a
# suite.json declares, the framework files beside it, Benchmark and Control on a test, on its rows and in the
# catalog, what the catalog build rejects, and what a run does with a custom suite whose framework file is wrong.
#
# The fixtures are in powershell/tests/fixtures/frameworks. valid/contoso is one suite with two frameworks and a
# test that has the prefix of neither. invalid/ has one suite for each thing that can be wrong with a framework.
# Every fixture test has the attributes of a test shipped with Maester, so the same files serve as a custom suite
# (a run) and as built-in tests (the catalog build).
BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
    $script:manifest = (Resolve-Path "$PSScriptRoot/../../../Maester.psd1").Path
    $script:fixtures = (Resolve-Path "$PSScriptRoot/../../fixtures/frameworks").Path
    $script:valid = Join-Path $script:fixtures 'valid'
    $script:invalid = Join-Path $script:fixtures 'invalid'
    $script:pwsh = (Get-Process -Id $PID).Path

    # The frameworks of the suite.json in a folder, as the inventory loads them.
    function Get-Framework {
        param([string] $Folder)
        InModuleScope Maester -Parameters @{ F = $Folder } {
            Get-MtSuiteFramework -Suite (Get-Content -LiteralPath (Join-Path $F 'suite.json') -Raw | ConvertFrom-Json) -Folder $F
        }
    }

    # A suite folder in TestDrive with the given Frameworks declaration and framework files (key to text).
    function New-SuiteFolder {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([object[]] $Declaration, [hashtable] $File = @{})
        $folder = Join-Path $TestDrive ('suite' + [guid]::NewGuid().ToString('n'))
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'frameworks') -Force
        ConvertTo-Json -InputObject @{ Id = 'Contoso'; Frameworks = @($Declaration) } -Depth 5 | Set-Content (Join-Path $folder 'suite.json')
        foreach ($key in $File.Keys) { Set-Content -LiteralPath (Join-Path $folder "frameworks/$key.json") -Value $File[$key] }
        $folder
    }

    # The tests of a folder by ID, with the warnings reading them wrote.
    function Read-Suite {
        param([string] $Path)
        $warnings = $null
        $tests = @{}
        foreach ($t in @(Get-MtTest -Path $Path -WarningVariable warnings -WarningAction SilentlyContinue)) { $tests[$t.Id] = $t }
        [pscustomobject]@{ Tests = $tests; Warnings = @($warnings | ForEach-Object { $_.Message }) }
    }
}

Describe 'Frameworks of a suite' {
    It 'Reads the frameworks a suite.json declares, each with the requirements of its file by test ID' {
        $frameworks = @(Get-Framework (Join-Path $script:valid 'contoso'))
        $frameworks | Should -HaveCount 2
        $frameworks.Key | Should -Be @('contoso-baseline', 'contoso-cloud')
        $frameworks.IdPrefix | Should -Be @('CONTOSO.BL.', 'CONTOSO.CLOUD.')
        $frameworks.IsValid | Should -Be @($true, $true)
        $frameworks[0].Name | Should -Be 'Contoso Security Baseline'
        $frameworks[0].Url | Should -Be 'https://example.com/contoso-baseline'
        Split-Path $frameworks[0].File -Leaf | Should -Be 'contoso-baseline.json'
        @($frameworks[0].Requirements).Count | Should -Be 3 -Because 'a requirement no test implements is still a requirement of the file'
        @($frameworks[0].ByTest.Keys | Sort-Object) | Should -Be @('CONTOSO.BL.1.1', 'CONTOSO.BL.1.10', 'CONTOSO.BL.1.10.EXT')
        $frameworks[0].ByTest.ContainsKey('contoso.bl.1.1') | Should -BeTrue -Because 'test IDs are matched whatever their case'
        $frameworks[1].ByTest['CONTOSO.CLOUD.NET-7'].Related | Should -Be @('nist-800-53-r5:SC-7', 'nist-800-53-r5:AC-4')
    }

    It 'Takes the version of the suite.json, and the version of the file when the suite.json gives none' {
        $frameworks = @(Get-Framework (Join-Path $script:valid 'contoso'))
        $frameworks[0].Version | Should -BeExactly '2.1'
        $frameworks[1].Version | Should -BeExactly '2025-03'
    }

    It 'Returns nothing for a suite without Frameworks' {
        @(InModuleScope Maester -Parameters @{ F = $TestDrive } { Get-MtSuiteFramework -Suite ([pscustomobject]@{ Id = 'Contoso' }) -Folder $F }) | Should -HaveCount 0
        @(InModuleScope Maester -Parameters @{ F = $TestDrive } { Get-MtSuiteFramework -Suite $null -Folder $F }) | Should -HaveCount 0
    }

    It 'Reports <Case> and reads no file for it' -ForEach @(
        @{ Case = 'a key with capital letters'; Declaration = @{ Key = 'Contoso'; IdPrefix = 'CONTOSO.' }; Message = "*suite.json: a Frameworks entry has the Key 'Contoso'*" }
        @{ Case = 'a key that is a path'; Declaration = @{ Key = '../contoso'; IdPrefix = 'CONTOSO.' }; Message = "*a Frameworks entry has the Key '../contoso'*" }
        @{ Case = 'an entry without a key'; Declaration = @{ IdPrefix = 'CONTOSO.' }; Message = "*a Frameworks entry has the Key ''*" }
        @{ Case = 'an entry that is not an object'; Declaration = 'contoso'; Message = "*a Frameworks entry has the Key ''*" }
    ) {
        # The file exists, so only the key keeps it from being read.
        $folder = New-SuiteFolder -Declaration $Declaration -File @{ contoso = '{ "Framework": "contoso", "Requirements": [] }' }
        $framework = @(Get-Framework $folder)
        $framework | Should -HaveCount 1
        $framework[0].IsValid | Should -BeFalse
        $framework[0].File | Should -BeNullOrEmpty
        $framework[0].Problems | Should -HaveCount 1
        $framework[0].Problems[0] | Should -BeLike $Message
    }

    It 'Reports a framework without an IdPrefix' {
        $folder = New-SuiteFolder -Declaration @{ Key = 'contoso'; Version = '1.0' } -File @{ contoso = '{ "Framework": "contoso", "Requirements": [] }' }
        $framework = @(Get-Framework $folder)
        $framework[0].IsValid | Should -BeFalse
        $framework[0].Problems | Should -HaveCount 1
        $framework[0].Problems[0] | Should -BeLike "*suite.json: the framework 'contoso' has no IdPrefix."
    }

    It 'Reports a key or a prefix that two frameworks of a suite share' {
        $file = '{ "Framework": "contoso", "Requirements": [] }'
        $sameKey = @(Get-Framework (New-SuiteFolder -Declaration @{ Key = 'contoso'; IdPrefix = 'A.' }, @{ Key = 'contoso'; IdPrefix = 'B.' } -File @{ contoso = $file }))
        $sameKey[0].IsValid | Should -BeTrue
        $sameKey[1].Problems | Should -HaveCount 1
        $sameKey[1].Problems[0] | Should -BeLike "*the framework 'contoso' is declared more than once."

        $samePrefix = @(Get-Framework (New-SuiteFolder -Declaration @{ Key = 'contoso'; IdPrefix = 'A.' }, @{ Key = 'fabrikam'; IdPrefix = 'a.' } -File @{ contoso = $file; fabrikam = $file.Replace('contoso', 'fabrikam') }))
        $samePrefix[1].Problems | Should -HaveCount 1
        $samePrefix[1].Problems[0] | Should -BeLike "*the IdPrefix 'a.' of the framework 'fabrikam' is used by another framework of the suite."
    }

    It 'Reports <Case> in a framework file' -ForEach @(
        @{ Case = 'text that is not JSON'; Content = '{ "Framework": "contoso", '; Message = '*contoso.json: it is not valid JSON.' }
        @{ Case = 'a list'; Content = '[1, 2]'; Message = '*contoso.json: it must hold one JSON object.' }
        @{ Case = 'nothing'; Content = ''; Message = '*contoso.json: it must hold one JSON object.' }
        @{ Case = 'a requirement whose Id is a number'; Content = '{ "Framework": "contoso", "Requirements": [ { "Id": 1.10, "Tests": ["CONTOSO.1"] } ] }'; Message = '*contoso.json: every requirement needs an Id written as a string.' }
        @{ Case = 'a requirement without an Id'; Content = '{ "Framework": "contoso", "Requirements": [ { "Tests": ["CONTOSO.1"] } ] }'; Message = '*contoso.json: every requirement needs an Id written as a string.' }
        @{ Case = 'a requirement listed twice'; Content = '{ "Framework": "contoso", "Requirements": [ { "Id": "R1" }, { "Id": "r1" } ] }'; Message = '*contoso.json: the requirement r1 is listed more than once.' }
        @{ Case = 'a Tests entry that is not a test ID'; Content = '{ "Framework": "contoso", "Requirements": [ { "Id": "R1", "Tests": [7] } ] }'; Message = '*contoso.json: the requirement R1 has a Tests entry that is not a test ID.' }
        @{ Case = 'a missing Framework key'; Content = '{ "Requirements": [] }'; Message = "*contoso.json: Framework is ''; the suite.json declares the key 'contoso'." }
    ) {
        $folder = New-SuiteFolder -Declaration @{ Key = 'contoso'; Version = '1.0'; IdPrefix = 'CONTOSO.' } -File @{ contoso = $Content }
        $framework = @(Get-Framework $folder)
        $framework[0].IsValid | Should -BeFalse
        $framework[0].Problems | Should -HaveCount 1
        $framework[0].Problems[0] | Should -BeLike $Message
    }

    It 'Takes the framework with the longest prefix when the prefixes of two match' {
        InModuleScope Maester {
            $general = [pscustomobject]@{ Key = 'general'; IdPrefix = 'FX.' }
            $specific = [pscustomobject]@{ Key = 'specific'; IdPrefix = 'FX.A.' }
            (Select-MtTestFramework -Id 'FX.A.1' -Framework $general, $specific).Key | Should -Be 'specific'
            (Select-MtTestFramework -Id 'FX.A.1' -Framework $specific, $general).Key | Should -Be 'specific'
            (Select-MtTestFramework -Id 'fx.b.1' -Framework $general, $specific).Key | Should -Be 'general' -Because 'a prefix matches whatever its case'
            Select-MtTestFramework -Id 'OTHER.1' -Framework $general, $specific | Should -BeNullOrEmpty
            Select-MtTestFramework -Id 'FX.A.1' -Framework @() | Should -BeNullOrEmpty
        }
    }

    It 'Reads the suite.json and its framework files once for the tests of a folder' {
        Mock -ModuleName Maester Get-MtSuiteFramework { }
        $tests = @(InModuleScope Maester -Parameters @{ F = $script:valid } { Get-MtNativeTestInventory -Path $F -Root $F })
        $tests | Should -HaveCount 5
        Should -Invoke Get-MtSuiteFramework -ModuleName Maester -Times 1 -Exactly
    }
}

Describe 'Benchmark and Control of a test' {
    BeforeAll {
        $script:suite = Read-Suite $script:valid
        $script:tests = $script:suite.Tests
    }

    It 'Reads the fixture suite without errors or warnings' {
        $script:tests.Count | Should -Be 5
        @($script:tests.Values | Where-Object { -not $_.IsValid }) | Should -HaveCount 0
        $script:suite.Warnings | Should -HaveCount 0
    }

    It 'Gives <Id> the requirement <Requirement> of <Framework> <Version>' -ForEach @(
        @{ Id = 'CONTOSO.BL.1.1'; Framework = 'contoso-baseline'; Version = '2.1'; Requirement = '1.1' }
        @{ Id = 'CONTOSO.BL.1.10'; Framework = 'contoso-baseline'; Version = '2.1'; Requirement = '1.10' }
        @{ Id = 'CONTOSO.CLOUD.NET-7'; Framework = 'contoso-cloud'; Version = '2025-03'; Requirement = 'NET-7' }
    ) {
        $benchmark = $script:tests[$Id].Benchmark
        $benchmark.Framework | Should -BeExactly $Framework
        $benchmark.Version | Should -BeExactly $Version
        $benchmark.Requirement | Should -BeExactly $Requirement
        @($benchmark.PSObject.Properties.Name)[0..2] | Should -Be @('Framework', 'Version', 'Requirement')
    }

    It 'Gives the two tests of one requirement the same requirement' {
        $script:tests['CONTOSO.BL.1.10.EXT'].Benchmark.Requirement | Should -BeExactly '1.10'
        $script:tests['CONTOSO.BL.1.10.EXT'].Benchmark.Framework | Should -Be 'contoso-baseline'
    }

    It 'Adds the facts of the requirement, and not its Id, Tests and Related' {
        $baseline = $script:tests['CONTOSO.BL.1.10'].Benchmark
        $baseline.Level | Should -Be 'L2'
        $baseline.Profile | Should -Be @('Standard', 'Strict')
        @($baseline.PSObject.Properties.Name) | Should -Be @('Framework', 'Version', 'Requirement', 'Level', 'Profile')

        $cloud = $script:tests['CONTOSO.CLOUD.NET-7'].Benchmark
        $cloud.Criticality | Should -Be 'SHALL'
        $cloud.Upstream.Status | Should -Be 'Moved'
        $cloud.Upstream.Id | Should -Be 'NET-9v2'
        $cloud.Upstream.From | Should -Be 'NET-7v1'
        @($cloud.PSObject.Properties.Name) | Should -Be @('Framework', 'Version', 'Requirement', 'Criticality', 'Upstream')
    }

    It 'Carries Benchmark as null on a test whose ID has the prefix of no framework of its suite' {
        $other = $script:tests['CONTOSO.OTHER.1']
        $other.PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty -Because 'the property is never left out'
        $other.Benchmark | Should -BeNullOrEmpty
    }

    It 'Lists the Control values of the test first, then the Related references of its requirement, each once' {
        # The test declares contoso-policy:P-12 and IA-2(1); the requirement relates to IA-5, IA-2(1) and A.5.17.
        $script:tests['CONTOSO.BL.1.1'].Control | Should -BeExactly @('contoso-policy:P-12', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
    }

    It 'Gives a test without Control of its own the Related references of its requirement, in the order of the file' {
        $script:tests['CONTOSO.CLOUD.NET-7'].Control | Should -BeExactly @('nist-800-53-r5:SC-7', 'nist-800-53-r5:AC-4')
    }

    It 'Leaves Control as the test wrote it when there is nothing to add' {
        $script:tests['CONTOSO.OTHER.1'].Control | Should -BeExactly @('contoso-policy:P-1')
        @($script:tests['CONTOSO.BL.1.10'].Control).Count | Should -Be 0 -Because 'its requirement has no Related references'
    }

    It 'Takes the more specific of two frameworks whose prefixes both match a test' {
        $folder = New-SuiteFolder -Declaration @{ Key = 'general'; Version = '1'; IdPrefix = 'FX.' }, @{ Key = 'specific'; Version = '2'; IdPrefix = 'FX.A.' } -File @{
            general  = '{ "Framework": "general", "Requirements": [ { "Id": "B-1", "Tests": ["FX.B.1"] } ] }'
            specific = '{ "Framework": "specific", "Requirements": [ { "Id": "A-1", "Tests": ["FX.A.1"] } ] }'
        }
        foreach ($id in 'FX.A.1', 'FX.B.1') {
            "function Test-$($id -replace '\.', '') {`n    [MaesterTest(Id = '$id', Title = 'Title of $id', Service = 'None')]`n    [CmdletBinding()]`n    param()`n    `$true`n}" | Set-Content (Join-Path $folder "Test.$id.ps1")
            'Description.' | Set-Content (Join-Path $folder "Test.$id.md")
        }
        $read = Read-Suite $folder
        $read.Warnings | Should -HaveCount 0
        $read.Tests['FX.A.1'].Benchmark.Framework | Should -Be 'specific'
        $read.Tests['FX.A.1'].Benchmark.Requirement | Should -Be 'A-1'
        $read.Tests['FX.B.1'].Benchmark.Framework | Should -Be 'general'
    }
}

Describe 'Benchmark of the tests shipped with Maester' {
    BeforeAll {
        $script:builtIn = @(Get-MtTest)
        $script:byId = @{}
        foreach ($t in $script:builtIn) { $script:byId[$t.Id] = $t }
        $script:frameworkFiles = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -File -Filter '*.json' | Where-Object { $_.Directory.Name -eq 'frameworks' })
    }

    It 'Declares the benchmarks of the CIS and CISA suites in their suite.json' {
        $cis = Get-Content (Join-Path $script:repoRoot 'tests/cis/suite.json') -Raw | ConvertFrom-Json
        @($cis.Frameworks | ForEach-Object { "$($_.Key) $($_.Version) $($_.IdPrefix)" }) | Should -Be @('cis-m365 7.0.0 CIS.M365.', 'cis-github 1.2.0 CIS.GH.')
        $cisa = Get-Content (Join-Path $script:repoRoot 'tests/cisa/suite.json') -Raw | ConvertFrom-Json
        @($cisa.Frameworks).Count | Should -Be 1
        $cisa.Frameworks[0].Key | Should -Be 'cisa-scuba'
        $cisa.Frameworks[0].IdPrefix | Should -Be 'CISA.'
        $cisa.Frameworks[0].Version | Should -Not -BeNullOrEmpty
    }

    It 'Has a framework file for every declared framework and no problem in any of them' {
        @($script:frameworkFiles.Name | Sort-Object) | Should -Be @('cis-github.json', 'cis-m365.json', 'cisa-scuba.json')
        $problems = @(InModuleScope Maester { Get-MtFrameworkProblem -Test @(Get-MtTestCatalog) -Root (Get-MtMaesterTestFolderPath) })
        $problems | Should -BeNullOrEmpty
    }

    It 'Gives every test with the prefix <Prefix> a Benchmark of <Framework>' -ForEach @(
        @{ Prefix = 'CIS.M365.'; Framework = 'cis-m365'; Version = '7.0.0'; Count = 44 }
        @{ Prefix = 'CIS.GH.'; Framework = 'cis-github'; Version = '1.2.0'; Count = 5 }
        @{ Prefix = 'CISA.'; Framework = 'cisa-scuba'; Version = $null; Count = 79 }
    ) {
        $tests = @($script:builtIn | Where-Object { $_.Id.StartsWith($Prefix) })
        $tests.Count | Should -Be $Count
        @($tests | Where-Object { -not $_.Benchmark -or $_.Benchmark.Framework -cne $Framework } | ForEach-Object Id) | Should -BeNullOrEmpty
        if ($Version) { @($tests | Where-Object { $_.Benchmark.Version -cne $Version } | ForEach-Object Id) | Should -BeNullOrEmpty }
        @($tests | Where-Object { -not $_.Benchmark.Version } | ForEach-Object Id) | Should -BeNullOrEmpty
        # The requirement a built-in test implements is the rest of its ID after the prefix.
        @($tests | Where-Object { "$Prefix$($_.Benchmark.Requirement)" -cne $_.Id } | ForEach-Object Id) | Should -BeNullOrEmpty
    }

    It 'Carries Benchmark as null on every other test' {
        $others = @($script:builtIn | Where-Object { $_.Id -notlike 'CIS.*' -and $_.Id -notlike 'CISA.*' })
        $others.Count | Should -BeGreaterThan 600
        @($others | Where-Object { -not $_.PSObject.Properties['Benchmark'] -or $null -ne $_.Benchmark } | ForEach-Object Id) | Should -BeNullOrEmpty
    }

    It 'Gives a CIS test its level and profiles' {
        $benchmark = $script:byId['CIS.M365.1.1.1'].Benchmark
        $benchmark.Requirement | Should -BeExactly '1.1.1'
        $benchmark.Level | Should -Be 'L1'
        $benchmark.Profile | Should -Be @('E3 Level 1')
        $script:byId['CIS.M365.2.1.1'].Benchmark.Level | Should -Be 'L2'
        $script:byId['CIS.GH.1.2.2'].Benchmark.Profile | Should -Be @('GH Level 1')
        $cis = @($script:builtIn | Where-Object { $_.Id -like 'CIS.*' })
        @($cis | Where-Object { $_.Benchmark.Level -cnotin 'L1', 'L2' -or @($_.Benchmark.Profile).Count -eq 0 } | ForEach-Object Id) | Should -BeNullOrEmpty
    }

    It 'Gives a CISA test its criticality, where the policy stands upstream, and the NIST SP 800-53 controls as Control' {
        $test = $script:byId['CISA.MS.AAD.1.1']
        $test.Benchmark.Requirement | Should -BeExactly 'MS.AAD.1.1'
        $test.Benchmark.Criticality | Should -Be 'SHALL'
        $test.Benchmark.Upstream.Status | Should -Be 'Current'
        $test.Benchmark.Upstream.Id | Should -Be 'MS.AAD.1.1v1'
        $test.Control | Should -Be @('nist-800-53-r5:CM-7')
        $script:byId['CISA.MS.EXO.8.1'].Benchmark.Upstream.Status | Should -Be 'Moved'
        $script:byId['CISA.MS.EXO.8.3'].Benchmark.Upstream.Status | Should -Be 'Removed'

        $cisa = @($script:builtIn | Where-Object { $_.Id -like 'CISA.*' })
        @($cisa | Where-Object { $_.Benchmark.Criticality -cnotin 'SHALL', 'SHOULD' -or $_.Benchmark.Upstream.Status -cnotin 'Current', 'Moved', 'Removed', 'NotFound' } | ForEach-Object Id) | Should -BeNullOrEmpty
        @($cisa | Where-Object { @($_.Control).Count -gt 0 }).Count | Should -Be 71
        @($cisa | ForEach-Object { $_.Control } | Where-Object { $_ -cnotlike 'nist-800-53-r5:*' }) | Should -BeNullOrEmpty
    }

    It 'Keeps what the Maester 2.x benchmark tags said about each CIS test' {
        # L1, L2, "CIS E3 Level 1" and "CIS M365 v7.0.0" were tags in 2.x. The framework files are their home now.
        $legacy = InModuleScope Maester { (Get-MtLegacyTagTable).ByTest }
        $versionTag = @{ 'cis-m365' = 'CIS M365 v7.0.0'; 'cis-github' = 'CIS GitHub v1.2.0' }
        $offenders = foreach ($test in ($script:builtIn | Where-Object { $_.Id -like 'CIS.*' })) {
            $tags = @($legacy[$test.Id])
            $level = @($tags | Where-Object { $_ -in 'L1', 'L2' })
            $profiles = @($tags | Where-Object { $_ -match '^CIS .+ Level \d$' } | ForEach-Object { $_ -replace '^CIS ', '' } | Sort-Object)
            if ($level.Count -gt 0 -and $level[0] -ne $test.Benchmark.Level) { "$($test.Id): level $($test.Benchmark.Level), tag $($level[0])" }
            if (($profiles -join '|') -ne (@($test.Benchmark.Profile | Sort-Object) -join '|')) { "$($test.Id): profiles $($test.Benchmark.Profile -join ', '), tags $($profiles -join ', ')" }
            if (@($test.Benchmark.Profile | Where-Object { $_ -notlike "* Level $($test.Benchmark.Level.Substring(1))" }).Count -gt 0) { "$($test.Id): level $($test.Benchmark.Level) with profiles $($test.Benchmark.Profile -join ', ')" }
            if ($tags -notcontains $versionTag[$test.Benchmark.Framework]) { "$($test.Id): $($test.Benchmark.Framework) $($test.Benchmark.Version) without the tag $($versionTag[$test.Benchmark.Framework])" }
        }
        $offenders | Should -BeNullOrEmpty
    }

    It 'Holds identifiers and facts in the framework files, not the text of a requirement' {
        $offenders = foreach ($file in $script:frameworkFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            foreach ($requirement in $content.Requirements) {
                foreach ($name in $requirement.PSObject.Properties.Name) {
                    if ($name -cnotin 'Id', 'Tests', 'Related', 'Level', 'Profile', 'Criticality', 'Upstream') { "$($file.Name): requirement $($requirement.Id) has $name" }
                }
            }
        }
        $offenders | Should -BeNullOrEmpty -Because 'benchmark text is licensed; a requirement is named by its ID, and its title is the title of the test'
    }
}

Describe 'Benchmark and Control on result rows' {
    BeforeAll {
        # A custom folder: the fixture suite and one Pester-format test.
        $script:runFolder = Join-Path $TestDrive 'run'
        Copy-Item -LiteralPath (Join-Path $script:valid 'contoso') -Destination $script:runFolder -Recurse
        "Describe 'Pester block' { It 'PES.1: pester test' { `$true | Should -BeTrue } }" | Set-Content (Join-Path $script:runFolder 'Pester.Tests.ps1')

        # Invoke-Maester calls Invoke-Pester, so the runs happen in a child process: all of them in one, for speed.
        # The built-in suites are read without a tenant: -DryRun runs no test, and a row says why its test would
        # not have run (no connection) or that it would have (DryRun).
        $scenarios = [ordered]@{
            Custom = '-SkipBuiltIn'
            Cis    = '-Suite cis -DryRun'
            Cisa   = '-Suite cisa -DryRun'
        }
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add("`$ErrorActionPreference = 'Continue'")
        $lines.Add("Import-Module '$script:manifest' -WarningAction SilentlyContinue")
        foreach ($name in $scenarios.Keys) {
            $lines.Add("try { `$null = Invoke-Maester -Path '$script:runFolder' -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputJsonFile '$(Join-Path $TestDrive "$name.json")' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue $($scenarios[$name]) } catch { }")
        }
        $null = & $script:pwsh -NoProfile -NonInteractive -Command ($lines -join [Environment]::NewLine) 2>&1

        function Get-Run { param([string] $Scenario) Get-Content (Join-Path $TestDrive "$Scenario.json") -Raw | ConvertFrom-Json }
    }

    It 'Returns Benchmark and the merged Control on the rows of Invoke-MtTest' {
        $rows = @{}
        foreach ($row in @(Invoke-MtTest -Path $script:valid 6>$null 3>$null)) { $rows[$row.Id] = $row }
        $rows.Count | Should -Be 5
        @($rows.Values | Where-Object Result -NE 'Passed') | Should -HaveCount 0
        $rows['CONTOSO.BL.1.1'].Benchmark.Requirement | Should -BeExactly '1.1'
        $rows['CONTOSO.BL.1.1'].Benchmark.Level | Should -Be 'L1'
        $rows['CONTOSO.BL.1.1'].Control | Should -BeExactly @('contoso-policy:P-12', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
        $rows['CONTOSO.OTHER.1'].PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty
        $rows['CONTOSO.OTHER.1'].Benchmark | Should -BeNullOrEmpty
        $rows['CONTOSO.OTHER.1'].Control | Should -BeExactly @('contoso-policy:P-1')
    }

    It 'Writes Benchmark with the facts of the requirement to the result of a run' {
        $rows = (Get-Run 'Custom').Tests
        $row = $rows | Where-Object Id -EQ 'CONTOSO.CLOUD.NET-7'
        $row.Result | Should -Be 'Passed'
        $row.Benchmark.Framework | Should -BeExactly 'contoso-cloud'
        $row.Benchmark.Version | Should -BeExactly '2025-03'
        $row.Benchmark.Requirement | Should -BeExactly 'NET-7'
        $row.Benchmark.Criticality | Should -Be 'SHALL'
        $row.Benchmark.Upstream.Status | Should -Be 'Moved' -Because 'the nested object is written whole, not as a type name'
        $row.Benchmark.Upstream.From | Should -Be 'NET-7v1'
        $row.Control | Should -Be @('nist-800-53-r5:SC-7', 'nist-800-53-r5:AC-4')

        $baseline = $rows | Where-Object Id -EQ 'CONTOSO.BL.1.10'
        $baseline.Benchmark.Requirement | Should -BeExactly '1.10'
        $baseline.Benchmark.Profile | Should -Be @('Standard', 'Strict')
        ($rows | Where-Object Id -EQ 'CONTOSO.BL.1.1').Control | Should -Be @('contoso-policy:P-12', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
    }

    It 'Writes Benchmark as null on a native row without a requirement and on a Pester-format row' {
        $json = Get-Content (Join-Path $TestDrive 'Custom.json') -Raw
        $rows = ($json | ConvertFrom-Json).Tests
        foreach ($id in 'CONTOSO.OTHER.1', 'PES.1') {
            $row = $rows | Where-Object Id -EQ $id
            $row.Result | Should -Be 'Passed' -Because $id
            $row.PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty -Because "${id}: the field is never left out"
            $row.Benchmark | Should -BeNullOrEmpty -Because $id
        }
        ($rows | Where-Object Id -EQ 'PES.1').Format | Should -Be 'Pester'
        $json | Should -Match '"Benchmark":\s*null'
        InModuleScope Maester { (Get-MtRowAttribute).Contains('Benchmark') } | Should -BeTrue
        InModuleScope Maester { @((Get-MtRowAttribute).Keys)[-1] } | Should -Be 'Benchmark'
    }

    It 'Gives the rows of the CIS suite their Benchmark without a tenant' {
        $rows = @((Get-Run 'Cis').Tests | Where-Object Suite -EQ 'CIS')
        $rows.Count | Should -Be 49
        @($rows | Where-Object { $_.Result -notin 'NotRun', 'Skipped' -or $_.ReasonCode -eq 'NotSelected' } | ForEach-Object Id) | Should -BeNullOrEmpty -Because 'the suite is selected and nothing runs'
        @($rows | Where-Object { $_.Benchmark.Framework -cnotin 'cis-m365', 'cis-github' -or $_.Benchmark.Level -cnotin 'L1', 'L2' -or -not $_.Benchmark.Requirement } | ForEach-Object Id) | Should -BeNullOrEmpty
        $row = $rows | Where-Object Id -EQ 'CIS.M365.1.1.1'
        $row.Benchmark.Version | Should -BeExactly '7.0.0'
        $row.Benchmark.Profile | Should -Be @('E3 Level 1')
    }

    It 'Gives the rows of the CISA suite their Benchmark and the NIST SP 800-53 controls without a tenant' {
        $run = Get-Run 'Cisa'
        $rows = @($run.Tests | Where-Object Suite -EQ 'CISA')
        $rows.Count | Should -Be 79
        @($rows | Where-Object { $_.Benchmark.Framework -cne 'cisa-scuba' -or -not $_.Benchmark.Criticality } | ForEach-Object Id) | Should -BeNullOrEmpty
        @($rows | Where-Object { @($_.Control).Count -gt 0 }).Count | Should -Be 71
        $row = $rows | Where-Object Id -EQ 'CISA.MS.AAD.3.1'
        $row.Benchmark.Requirement | Should -BeExactly 'MS.AAD.3.1'
        $row.Benchmark.Upstream.Id | Should -Be 'MS.AAD.3.1v1'
        $row.Control | Should -Be @('nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-2(2)', 'nist-800-53-r5:IA-5c', 'nist-800-53-r5:IA-5g', 'nist-800-53-r5:IA-2(8)')
        # A test of another suite is in the result too, not selected, and has no Benchmark.
        $other = $run.Tests | Where-Object Id -EQ 'MT.1001'
        $other.ReasonCode | Should -Be 'NotSelected'
        $other.PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty
        $other.Benchmark | Should -BeNullOrEmpty
    }
}

Describe 'A custom suite with a framework problem' {
    It 'Warns about <Case> and leaves the tests of the framework without a Benchmark' -ForEach @(
        @{ Case = 'a framework without a file'; Folder = 'missing-file'; Id = 'FXM.1'; Message = "Ignoring the framework 'fx-missing' of *suite.json*, so its tests have no Benchmark. *fx-missing.json: the file does not exist.*" }
        @{ Case = 'a file that names another key'; Folder = 'wrong-key'; Id = 'FXK.1'; Message = "Ignoring the framework 'fx-key' of *fx-key.json: Framework is 'fx-other'; the suite.json declares the key 'fx-key'.*" }
        @{ Case = 'a Related reference that is not a control'; Folder = 'bad-related'; Id = 'FXR.1'; Message = "Ignoring the framework 'fx-related' of *fx-related.json: the requirement R1 has the Related reference 'NIST-800-53-R5:IA-3', which is not written <framework-key>:<control-id>*" }
        @{ Case = 'a test listed twice'; Folder = 'listed-twice'; Id = 'FXT.1'; Message = "Ignoring the framework 'fx-twice' of *fx-twice.json: the test FXT.1 is listed 2 times (requirements R1, R2).*" }
    ) {
        $read = Read-Suite (Join-Path $script:invalid $Folder)
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike $Message
        $read.Tests[$Id].IsValid | Should -BeTrue -Because 'the test itself is fine'
        $read.Tests[$Id].PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty
        $read.Tests[$Id].Benchmark | Should -BeNullOrEmpty
        @($read.Tests[$Id].Control).Count | Should -Be 0
    }

    It 'Says in the warning that the file and the suite.json disagree about the version' {
        (Read-Suite (Join-Path $script:invalid 'wrong-key')).Warnings[0] | Should -BeLike "*fx-key.json: Version is '2.0'; the suite.json declares the version '1.0'.*"
    }

    It 'Warns once about a file that is not valid JSON, whatever the number of tests' {
        $folder = Join-Path $TestDrive 'bad-json'
        Copy-Item -LiteralPath (Join-Path $script:invalid 'unlisted-test') -Destination $folder -Recurse
        '{ "Framework": "fx-unlisted", ' | Set-Content (Join-Path $folder 'frameworks/fx-unlisted.json')
        $read = Read-Suite $folder
        $read.Tests.Count | Should -Be 2
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike "Ignoring the framework 'fx-unlisted' of *fx-unlisted.json: it is not valid JSON."
        @($read.Tests.Values | Where-Object { $null -ne $_.Benchmark }) | Should -HaveCount 0
    }

    It 'Warns about a test that has the prefix and is not in the file, and keeps the Benchmark of the tests that are' {
        $read = Read-Suite (Join-Path $script:invalid 'unlisted-test')
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike "These tests have the IdPrefix 'FXL.' of the framework 'fx-unlisted' but *fx-unlisted.json' does not list them, so they have no Benchmark: FXL.2."
        $read.Tests['FXL.1'].Benchmark.Requirement | Should -Be 'R1'
        $read.Tests['FXL.2'].Benchmark | Should -BeNullOrEmpty
    }

    It 'Does not warn about <Case>, which only the catalog build can know' -ForEach @(
        @{ Case = 'a file that names a test the folder does not have'; Folder = 'unknown-test'; With = 'FXU.1'; Without = $null }
        @{ Case = 'a listed test whose ID does not have the prefix'; Folder = 'wrong-prefix'; With = 'FXP.1'; Without = 'FXQ.1' }
    ) {
        $read = Read-Suite (Join-Path $script:invalid $Folder)
        $read.Warnings | Should -HaveCount 0
        $read.Tests[$With].Benchmark.Requirement | Should -Be 'R1'
        if ($Without) { $read.Tests[$Without].Benchmark | Should -BeNullOrEmpty }
    }

    It 'Never stops a run: every test still runs, with or without a Benchmark' {
        $warnings = $null
        $rows = @(Invoke-MtTest -Path $script:invalid -WarningVariable warnings -WarningAction SilentlyContinue 6>$null)
        $rows.Count | Should -Be 9
        @($rows | Where-Object Result -NE 'Passed' | ForEach-Object { "$($_.Id): $($_.Result) $($_.ReasonDetail)" }) | Should -BeNullOrEmpty
        @($rows | Where-Object { $_.Benchmark } | ForEach-Object Id | Sort-Object) | Should -Be @('FXL.1', 'FXP.1', 'FXU.1')
        @($warnings | Where-Object { $_.Message -like 'Ignoring the framework*' }).Count | Should -Be 4
        @($warnings | Where-Object { $_.Message -like 'These tests have the IdPrefix*' }).Count | Should -Be 1
    }
}

Describe 'Catalog build' {
    BeforeAll {
        # The build only writes inside the repository, so its output goes there and is removed afterwards.
        $script:buildOutput = Join-Path $script:repoRoot ".tmp-maester-build-tests-$([guid]::NewGuid())"
        $script:buildScript = Join-Path $script:repoRoot 'build/Build-MaesterModule.ps1'

        # Builds the module with the given folder as the built-in tests. Returns the exit code and, when the
        # build stopped, the message it stopped with, one problem on a line.
        function Invoke-Build {
            param([string] $TestsRoot, [string] $Name)
            $output = Join-Path $script:buildOutput $Name
            $command = "try { & '$script:buildScript' -TestsRoot '$TestsRoot' -OutputRoot '$output' *> `$null; exit 0 } catch { [Console]::Out.WriteLine(`$_.Exception.Message); exit 1 }"
            $lines = @(& $script:pwsh -NoProfile -NonInteractive -Command $command 2>&1 | ForEach-Object { "$_" })
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Lines = $lines; Output = $output }
        }

        $script:expectedProblems = @(
            "bad-related/frameworks/fx-related.json: the requirement R1 has the Related reference 'NIST-800-53-R5:IA-3', which is not written <framework-key>:<control-id> with a lowercase key, for example nist-800-53-r5:IA-2(1)."
            "bad-related/frameworks/fx-related.json: the requirement R1 has the Related reference 'IA-4', which is not written <framework-key>:<control-id> with a lowercase key, for example nist-800-53-r5:IA-2(1)."
            'listed-twice/frameworks/fx-twice.json: the test FXT.1 is listed 2 times (requirements R1, R2). A test is listed once.'
            "missing-file/frameworks/fx-missing.json: the file does not exist. The suite.json declares the framework 'fx-missing'."
            'unknown-test/frameworks/fx-unknown.json: the requirement R2 names the test FXU.404, which is not a test of the suite.'
            "unlisted-test/frameworks/fx-unlisted.json: the test FXL.2 has the IdPrefix 'FXL.' and is not listed in a requirement. Every test with the prefix is listed once."
            "wrong-key/frameworks/fx-key.json: Framework is 'fx-other'; the suite.json declares the key 'fx-key'."
            "wrong-key/frameworks/fx-key.json: Version is '2.0'; the suite.json declares the version '1.0'."
            "wrong-prefix/frameworks/fx-prefix.json: the requirement R2 names the test FXQ.1, whose ID does not start with the IdPrefix 'FXP.'."
        )
        [array]::Sort($script:expectedProblems, [System.StringComparer]::Ordinal)
        # The messages with the path relative to the fixture folder and forward slashes, in a fixed order.
        function ConvertTo-RelativeProblem {
            param([string[]] $Problem)
            $relative = [string[]]@($Problem | ForEach-Object { $_.Replace($script:invalid, '').Replace('\', '/').TrimStart('/') })
            [array]::Sort($relative, [System.StringComparer]::Ordinal)
            $relative
        }
    }
    AfterAll {
        if (Test-Path -LiteralPath $script:buildOutput) { Remove-Item -LiteralPath $script:buildOutput -Recurse -Force }
    }

    It 'Finds every problem of the framework files, and names the file and the ID in each message' {
        $problems = @(InModuleScope Maester -Parameters @{ R = $script:invalid } {
                $tests = @(Get-MtNativeTestInventory -Path $R -Root $R -BuiltIn -WarningAction SilentlyContinue)
                Get-MtFrameworkProblem -Test $tests -Root $R
            })
        ConvertTo-RelativeProblem $problems | Should -Be $script:expectedProblems
        @($problems | Where-Object { -not $_.StartsWith($script:invalid) }) | Should -HaveCount 0 -Because 'a message starts with the full path of the file'
    }

    It 'Finds no problem in a suite whose framework files are right' {
        $problems = @(InModuleScope Maester -Parameters @{ R = $script:valid } {
                Get-MtFrameworkProblem -Test @(Get-MtNativeTestInventory -Path $R -Root $R -BuiltIn) -Root $R
            })
        $problems | Should -BeNullOrEmpty
    }

    It 'Checks the framework files of a suite that has no test' {
        $folder = New-SuiteFolder -Declaration @{ Key = 'contoso'; Version = '1.0'; IdPrefix = 'CONTOSO.' } -File @{ contoso = '{ "Framework": "contoso", "Requirements": [ { "Id": "R1", "Tests": ["CONTOSO.1"] } ] }' }
        $problems = @(InModuleScope Maester -Parameters @{ R = (Split-Path $folder -Parent) } { Get-MtFrameworkProblem -Test @() -Root $R })
        @($problems | Where-Object { $_ -like '*contoso.json: the requirement R1 names the test CONTOSO.1, which is not a test of the suite.' }) | Should -HaveCount 1
    }

    It 'Stops the build with those messages' {
        $build = Invoke-Build -TestsRoot $script:invalid -Name 'invalid'
        $build.ExitCode | Should -Be 1
        $build.Lines[0] | Should -Be 'Built-in native tests have 9 problem(s):' -Because 'the framework files are all that is wrong with the fixture tests'
        ConvertTo-RelativeProblem ($build.Lines | Select-Object -Skip 1) | Should -Be $script:expectedProblems
        Join-Path $build.Output 'Maester.TestCatalog.json' | Should -Not -Exist
    }

    It 'Ships the framework files beside the suite.json and writes Benchmark and Control to the catalog' {
        $build = Invoke-Build -TestsRoot $script:valid -Name 'valid'
        $build.ExitCode | Should -Be 0 -Because ($build.Lines -join "`n")
        Join-Path $build.Output 'builtin-pester/contoso/suite.json' | Should -Exist
        Join-Path $build.Output 'builtin-pester/contoso/frameworks/contoso-baseline.json' | Should -Exist
        Join-Path $build.Output 'builtin-pester/contoso/frameworks/contoso-cloud.json' | Should -Exist
        @(Get-ChildItem -LiteralPath (Join-Path $build.Output 'builtin-pester') -Recurse -File -Filter 'Test.*') | Should -HaveCount 0

        $catalog = Get-Content -LiteralPath (Join-Path $build.Output 'Maester.TestCatalog.json') -Raw | ConvertFrom-Json
        @($catalog.Suites.Contoso.Frameworks.Key) | Should -Be @('contoso-baseline', 'contoso-cloud')
        @($catalog.Tests).Count | Should -Be 5
        $test = $catalog.Tests | Where-Object Id -EQ 'CONTOSO.BL.1.1'
        $test.Benchmark.Framework | Should -BeExactly 'contoso-baseline'
        $test.Benchmark.Version | Should -BeExactly '2.1'
        $test.Benchmark.Requirement | Should -BeExactly '1.1'
        $test.Benchmark.Profile | Should -Be @('Standard')
        $test.Control | Should -Be @('contoso-policy:P-12', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
        ($catalog.Tests | Where-Object Id -EQ 'CONTOSO.CLOUD.NET-7').Benchmark.Upstream.Status | Should -Be 'Moved'
        $other = $catalog.Tests | Where-Object Id -EQ 'CONTOSO.OTHER.1'
        $other.PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty
        $other.Benchmark | Should -BeNullOrEmpty
    }

    It 'Gives the rows of the built module the Benchmark and Control of the catalog' {
        # The built module reads the catalog, not the framework files.
        $built = Join-Path $script:buildOutput 'valid/Maester.psd1'
        $built | Should -Exist -Because 'the test before this one builds the module'
        $out = Join-Path $TestDrive 'built-rows.json'
        $command = "Import-Module '$built' -WarningAction SilentlyContinue; @(Get-MtTest) + @(Invoke-MtTest -Id 'CONTOSO.*' 6>`$null 3>`$null) | Select-Object Id, Result, Benchmark, Control | ConvertTo-Json -Depth 6 | Set-Content '$out'"
        $null = & $script:pwsh -NoProfile -NonInteractive -Command $command 2>&1
        $objects = @(Get-Content -LiteralPath $out -Raw | ConvertFrom-Json)
        $objects.Count | Should -Be 10 -Because 'five tests and their five rows'
        foreach ($object in ($objects | Where-Object Id -EQ 'CONTOSO.BL.1.1')) {
            $object.Benchmark.Requirement | Should -BeExactly '1.1'
            $object.Benchmark.Level | Should -Be 'L1'
            $object.Control | Should -Be @('contoso-policy:P-12', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
        }
        @($objects | Where-Object { $_.Result -and $_.Result -ne 'Passed' }) | Should -HaveCount 0
        @($objects | Where-Object { $_.Id -eq 'CONTOSO.OTHER.1' -and $null -ne $_.Benchmark }) | Should -HaveCount 0
        @($objects | Where-Object { $_.Id -eq 'CONTOSO.CLOUD.NET-7' -and $_.Benchmark.Upstream.Id -eq 'NET-9v2' -and (@($_.Control) -join ',') -eq 'nist-800-53-r5:SC-7,nist-800-53-r5:AC-4' }) | Should -HaveCount 2
    }
}
