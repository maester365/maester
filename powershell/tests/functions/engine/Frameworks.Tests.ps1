# Benchmarks and framework files (docs/proposals/maester-3.0-test-attributes.md, section 6): the Frameworks a
# suite.json declares, the framework files beside it, the Control that maps a test to a requirement, Benchmark and
# Control on a test, on its rows and in the catalog, what the catalog build rejects, and what a run does with a
# custom suite whose framework file is wrong.
#
# The fixtures are in powershell/tests/fixtures/frameworks. valid/contoso is one suite with two frameworks and a
# test that maps to neither. invalid/ has one suite for each thing that can be wrong with a framework.
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

    # A native test in a folder, with the given Control values.
    function New-TestFile {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([string] $Folder, [string] $Id, [string[]] $Control)
        $list = @($Control | ForEach-Object { "'$_'" }) -join ', '
        $null = New-Item -ItemType Directory -Path $Folder -Force
        "function Test-$($Id -replace '\W', '') {`n    [MaesterTest(Id = '$Id', Title = 'Title of $Id', Control = ($list), Service = 'None')]`n    [CmdletBinding()]`n    param()`n    `$true`n}" | Set-Content (Join-Path $Folder "Test.$Id.ps1")
        'Description.' | Set-Content (Join-Path $Folder "Test.$Id.md")
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
    It 'Reads the frameworks a suite.json declares, each with the requirements of its file by Id' {
        $frameworks = @(Get-Framework (Join-Path $script:valid 'contoso'))
        $frameworks | Should -HaveCount 2
        $frameworks.Key | Should -Be @('contoso-baseline', 'contoso-cloud')
        $frameworks.IsValid | Should -Be @($true, $true)
        $frameworks[0].Name | Should -Be 'Contoso Security Baseline'
        $frameworks[0].Url | Should -Be 'https://example.com/contoso-baseline'
        Split-Path $frameworks[0].File -Leaf | Should -Be 'contoso-baseline.json'
        @($frameworks[0].Requirements).Count | Should -Be 3 -Because 'a requirement no test implements is still a requirement of the file'
        @($frameworks[0].ById.Keys | Sort-Object) | Should -Be @('1.1', '1.10', '9.9')
        $frameworks[0].ById['1.10'].Requirement.Level | Should -Be 'L2'
        $frameworks[1].ById.ContainsKey('net-7') | Should -BeFalse -Because 'a requirement Id is matched as it is written'
        $frameworks[1].ById['NET-7'].Related | Should -Be @('nist-800-53-r5:SC-7', 'nist-800-53-r5:AC-4')
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
        @{ Case = 'a key with capital letters'; Declaration = @{ Key = 'Contoso' }; Message = "*suite.json: a Frameworks entry has the Key 'Contoso'*" }
        @{ Case = 'a key that is a path'; Declaration = @{ Key = '../contoso' }; Message = "*a Frameworks entry has the Key '../contoso'*" }
        @{ Case = 'an entry without a key'; Declaration = @{ Version = '1.0' }; Message = "*a Frameworks entry has the Key ''*" }
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

    It 'Ignores an IdPrefix in the declaration and a Tests list on a requirement' {
        # Both mapped a test to a requirement before Control did. A file that still has them is read as if it had not.
        $cloud = @(Get-Framework (Join-Path $script:valid 'contoso'))[1]
        (Get-Content (Join-Path $script:valid 'contoso/suite.json') -Raw) | Should -Match '"IdPrefix"'
        $cloud.ById['NET-7'].Requirement.Tests | Should -Be @('CONTOSO.OTHER.1', 'CONTOSO.NONE.404')
        $cloud.IsValid | Should -BeTrue
        $cloud.PSObject.Properties['IdPrefix'] | Should -BeNullOrEmpty

        $folder = New-SuiteFolder -Declaration @{ Key = 'contoso'; IdPrefix = 7 } -File @{ contoso = '{ "Framework": "contoso", "Requirements": [ { "Id": "R1", "Tests": [7, null] }, { "Id": "R2", "Tests": "R1" } ] }' }
        $framework = @(Get-Framework $folder)
        $framework[0].Problems | Should -HaveCount 0
        @($framework[0].ById.Keys) | Should -Be @('R1', 'R2')
    }

    It 'Reports a key that a suite declares twice' {
        $file = '{ "Framework": "contoso", "Requirements": [] }'
        $sameKey = @(Get-Framework (New-SuiteFolder -Declaration @{ Key = 'contoso' }, @{ Key = 'contoso' } -File @{ contoso = $file }))
        $sameKey[0].IsValid | Should -BeTrue
        $sameKey[1].Problems | Should -HaveCount 1
        $sameKey[1].Problems[0] | Should -BeLike "*the framework 'contoso' is declared more than once."
    }

    It 'Reports <Case> in a framework file' -ForEach @(
        @{ Case = 'text that is not JSON'; Content = '{ "Framework": "contoso", '; Message = '*contoso.json: it is not valid JSON.' }
        @{ Case = 'a list'; Content = '[1, 2]'; Message = '*contoso.json: it must hold one JSON object.' }
        @{ Case = 'nothing'; Content = ''; Message = '*contoso.json: it must hold one JSON object.' }
        @{ Case = 'a requirement whose Id is a number'; Content = '{ "Framework": "contoso", "Requirements": [ { "Id": 1.10 } ] }'; Message = '*contoso.json: every requirement needs an Id written as a string.' }
        @{ Case = 'a requirement without an Id'; Content = '{ "Framework": "contoso", "Requirements": [ { "Level": "L1" } ] }'; Message = '*contoso.json: every requirement needs an Id written as a string.' }
        @{ Case = 'a requirement listed twice'; Content = '{ "Framework": "contoso", "Requirements": [ { "Id": "R1" }, { "Id": "r1" } ] }'; Message = '*contoso.json: the requirement r1 is listed more than once.' }
        @{ Case = 'a missing Framework key'; Content = '{ "Requirements": [] }'; Message = "*contoso.json: Framework is ''; the suite.json declares the key 'contoso'." }
    ) {
        $folder = New-SuiteFolder -Declaration @{ Key = 'contoso'; Version = '1.0' } -File @{ contoso = $Content }
        $framework = @(Get-Framework $folder)
        $framework[0].IsValid | Should -BeFalse
        $framework[0].Problems | Should -HaveCount 1
        $framework[0].Problems[0] | Should -BeLike $Message
    }

    It 'Finds a framework by its key, whatever suite declares it' {
        $keys = InModuleScope Maester -Parameters @{ R = $script:valid } {
            [pscustomobject]@{
                Own    = @((Get-MtFrameworkIndex -Root $R -BuiltIn).ByKey.Keys | Sort-Object)
                Custom = @((Get-MtFrameworkIndex -Root $R).ByKey.Keys | Sort-Object)
                None   = @((Get-MtFrameworkIndex).ByKey.Keys | Sort-Object)
            }
        }
        $keys.Own | Should -Be @('contoso-baseline', 'contoso-cloud') -Because 'the tests shipped with Maester refer to nothing outside their own folder'
        $keys.Custom | Should -Be @('cis-github', 'cis-m365', 'cisa-scuba', 'contoso-baseline', 'contoso-cloud', 'essential-eight', 'ism') -Because 'a custom test can also refer to a framework shipped with Maester'
        $keys.None | Should -Be @('cis-github', 'cis-m365', 'cisa-scuba', 'essential-eight', 'ism')
    }

    It 'Reports a key that two suites declare, names both files and keeps the first' {
        $index = InModuleScope Maester -Parameters @{ R = (Join-Path $script:invalid 'same-key') } { Get-MtFrameworkIndex -Root $R -BuiltIn }
        $index.Problems | Should -HaveCount 1
        $index.Problems[0] | Should -BeLike "*same-key?b?suite.json: the framework 'fx-same' is also declared by '*same-key?a?suite.json'. A framework key is declared by one suite*"
        $index.All | Should -HaveCount 2
        $index.ByKey['fx-same'].ById['R1'].Requirement.Level | Should -Be 'L1' -Because 'the suite in folder a comes first'
    }

    It 'Lets a framework shipped with Maester keep its key when a custom suite declares it too' {
        $folder = New-SuiteFolder -Declaration @{ Key = 'cis-m365'; Version = '0.1' } -File @{ 'cis-m365' = '{ "Framework": "cis-m365", "Requirements": [ { "Id": "1.1.1", "Level": "L9" } ] }' }
        New-TestFile -Folder $folder -Id 'CONTOSO.CIS.1' -Control 'cis-m365:1.1.1'
        $read = Read-Suite $folder
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike "*suite.json: the framework 'cis-m365' is also declared by '*cis?suite.json'*"
        $read.Tests['CONTOSO.CIS.1'].Benchmark.Version | Should -BeExactly '7.0.0'
        $read.Tests['CONTOSO.CIS.1'].Benchmark.Level | Should -Be 'L1'
    }

    It 'Reads the suite.json and its framework files once for the tests of a folder' {
        Mock -ModuleName Maester Get-MtSuiteFramework { }
        # -BuiltIn, so that the frameworks shipped with Maester are not read as well.
        $tests = @(InModuleScope Maester -Parameters @{ F = $script:valid } { Get-MtNativeTestInventory -Path $F -Root $F -BuiltIn })
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

    It 'Gives two tests that name one requirement the same requirement' {
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

    It 'Carries Benchmark as null on a test whose Control names no requirement of a framework' {
        $other = $script:tests['CONTOSO.OTHER.1']
        $other.PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty -Because 'the property is never left out'
        $other.Benchmark | Should -BeNullOrEmpty
    }

    It 'Does not map a test that only a Tests list of a framework file names' {
        # Requirement NET-7 of contoso-cloud still lists CONTOSO.OTHER.1.
        $script:tests['CONTOSO.OTHER.1'].Benchmark | Should -BeNullOrEmpty
        $script:tests['CONTOSO.OTHER.1'].Control | Should -BeExactly @('contoso-policy:P-1')
    }

    It 'Lists the Control values of the test first, then the Related references of its requirement, each once' {
        # The test declares contoso-policy:P-12, the requirement and IA-2(1); the requirement relates to IA-5, IA-2(1) and A.5.17.
        $script:tests['CONTOSO.BL.1.1'].Control | Should -BeExactly @('contoso-policy:P-12', 'contoso-baseline:1.1', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
        $script:tests['CONTOSO.BL.1.1'].Benchmark.Requirement | Should -BeExactly '1.1' -Because 'the reference need not be the first Control'
    }

    It 'Adds the Related references in the order of the file' {
        $script:tests['CONTOSO.CLOUD.NET-7'].Control | Should -BeExactly @('contoso-cloud:NET-7', 'nist-800-53-r5:SC-7', 'nist-800-53-r5:AC-4')
    }

    It 'Leaves Control as the test wrote it when there is nothing to add' {
        $script:tests['CONTOSO.OTHER.1'].Control | Should -BeExactly @('contoso-policy:P-1')
        $script:tests['CONTOSO.BL.1.10'].Control | Should -BeExactly @('contoso-baseline:1.10') -Because 'its requirement has no Related references'
    }

    It 'Takes the Benchmark from the first Control that names a requirement, and the Related references of every one' {
        $folder = New-SuiteFolder -Declaration @{ Key = 'alpha'; Version = '1' }, @{ Key = 'beta'; Version = '2' } -File @{
            alpha = '{ "Framework": "alpha", "Requirements": [ { "Id": "A-1", "Level": "L1", "Related": ["nist-800-53-r5:AC-2", "nist-800-53-r5:AC-1"] } ] }'
            beta  = '{ "Framework": "beta", "Requirements": [ { "Id": "B-1", "Level": "L2", "Related": ["nist-800-53-r5:AC-1", "alpha:A-1"] } ] }'
        }
        New-TestFile -Folder $folder -Id 'FX.BOTH.1' -Control 'other:X-1', 'beta:B-1', 'alpha:A-1'
        New-TestFile -Folder $folder -Id 'FX.CASE.1' -Control 'ALPHA:A-1'
        $read = Read-Suite $folder
        $read.Warnings | Should -HaveCount 0
        $both = $read.Tests['FX.BOTH.1']
        $both.Benchmark.Framework | Should -Be 'beta'
        $both.Benchmark.Version | Should -BeExactly '2'
        $both.Benchmark.Requirement | Should -Be 'B-1'
        $both.Benchmark.Level | Should -Be 'L2'
        $both.Control | Should -BeExactly @('other:X-1', 'beta:B-1', 'alpha:A-1', 'nist-800-53-r5:AC-1', 'nist-800-53-r5:AC-2')
        $read.Tests['FX.CASE.1'].Benchmark.Framework | Should -BeExactly 'alpha' -Because 'the framework key of a Control is read in lowercase'
    }

    It 'Skips a Control that names a requirement the file does not have, warns, and takes the next one' {
        $folder = New-SuiteFolder -Declaration @{ Key = 'alpha'; Version = '1' }, @{ Key = 'beta'; Version = '2' } -File @{
            alpha = '{ "Framework": "alpha", "Requirements": [ { "Id": "A-1" } ] }'
            beta  = '{ "Framework": "beta", "Requirements": [ { "Id": "B-1" } ] }'
        }
        New-TestFile -Folder $folder -Id 'FX.NEXT.1' -Control 'alpha:a-1', 'beta:B-1'
        $read = Read-Suite $folder
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike "These tests have a Control that names the framework 'alpha' and a requirement that '*alpha.json' does not have, so it gives them no Benchmark: FX.NEXT.1 (alpha:a-1)."
        $read.Tests['FX.NEXT.1'].Benchmark.Framework | Should -Be 'beta'
        $read.Tests['FX.NEXT.1'].Control | Should -BeExactly @('alpha:a-1', 'beta:B-1')
    }

    It 'Maps a custom test to a framework of another custom suite and to one shipped with Maester' {
        $root = Join-Path $TestDrive ('root' + [guid]::NewGuid().ToString('n'))
        $null = New-Item -ItemType Directory -Path (Join-Path $root 'one/frameworks') -Force
        '{ "Id": "One", "Frameworks": [ { "Key": "alpha", "Version": "1" } ] }' | Set-Content (Join-Path $root 'one/suite.json')
        '{ "Framework": "alpha", "Requirements": [ { "Id": "A-1", "Level": "L1" } ] }' | Set-Content (Join-Path $root 'one/frameworks/alpha.json')
        New-TestFile -Folder (Join-Path $root 'two') -Id 'FX.TWO.1' -Control 'alpha:A-1'
        New-TestFile -Folder (Join-Path $root 'two') -Id 'FX.TWO.2' -Control 'cisa-scuba:MS.AAD.3.1', 'alpha:A-1'
        '{ "Id": "Two" }' | Set-Content (Join-Path $root 'two/suite.json')

        $read = Read-Suite $root
        $read.Warnings | Should -HaveCount 0
        $read.Tests['FX.TWO.1'].Suite | Should -Be 'Two'
        $read.Tests['FX.TWO.1'].Benchmark.Framework | Should -Be 'alpha' -Because 'the suite One, which has no test, declares it'
        $shipped = $read.Tests['FX.TWO.2']
        $shipped.Benchmark.Framework | Should -Be 'cisa-scuba'
        $shipped.Benchmark.Requirement | Should -Be 'MS.AAD.3.1'
        $shipped.Benchmark.Criticality | Should -Be 'SHALL'
        $shipped.Control | Should -BeExactly @('cisa-scuba:MS.AAD.3.1', 'alpha:A-1', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-2(2)', 'nist-800-53-r5:IA-5c', 'nist-800-53-r5:IA-5g', 'nist-800-53-r5:IA-2(8)')

        # A file on its own: the frameworks shipped with Maester, and nothing the folder beside it declares.
        $single = @(Get-MtTest -Path (Join-Path $root 'two/Test.FX.TWO.2.ps1') -WarningAction SilentlyContinue)
        $single[0].Benchmark.Framework | Should -Be 'cisa-scuba'
    }
}

Describe 'Benchmark of the tests shipped with Maester' {
    BeforeAll {
        $script:builtIn = @(Get-MtTest)
        $script:byId = @{}
        foreach ($t in $script:builtIn) { $script:byId[$t.Id] = $t }
        $script:frameworkFiles = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -File -Filter '*.json' | Where-Object { $_.Directory.Name -eq 'frameworks' })
    }

    It 'Declares the benchmarks of the CIS, CISA and ASD suites in their suite.json' {
        $cis = Get-Content (Join-Path $script:repoRoot 'tests/cis/suite.json') -Raw | ConvertFrom-Json
        @($cis.Frameworks | ForEach-Object { "$($_.Key) $($_.Version)" }) | Should -Be @('cis-m365 7.0.0', 'cis-github 1.2.0')
        $cisa = Get-Content (Join-Path $script:repoRoot 'tests/cisa/suite.json') -Raw | ConvertFrom-Json
        @($cisa.Frameworks).Count | Should -Be 1
        $cisa.Frameworks[0].Key | Should -Be 'cisa-scuba'
        @(@($cis.Frameworks) + @($cisa.Frameworks) | Where-Object { $_.PSObject.Properties['IdPrefix'] }) | Should -HaveCount 0 -Because 'a test is mapped by its Control, not by the prefix of its ID'
        $cisa.Frameworks[0].Version | Should -Not -BeNullOrEmpty
        $asd = Get-Content (Join-Path $script:repoRoot 'tests/asd/suite.json') -Raw | ConvertFrom-Json
        @($asd.Frameworks.Key) | Should -Be @('essential-eight', 'ism')
        # Both come from one ISM OSCAL release, so they carry one version.
        @($asd.Frameworks.Version | Sort-Object -Unique).Count | Should -Be 1
        $asd.Frameworks[0].Version | Should -Not -BeNullOrEmpty
    }

    It 'Has a framework file for every declared framework and no problem in any of them' {
        @($script:frameworkFiles.Name | Sort-Object) | Should -Be @('cis-github.json', 'cis-m365.json', 'cisa-scuba.json', 'essential-eight.json', 'ism.json')
        $problems = @(InModuleScope Maester { Get-MtFrameworkProblem -Test @(Get-MtTestCatalog) -Root (Get-MtMaesterTestFolderPath) })
        $problems | Should -BeNullOrEmpty
    }

    It 'Gives every <Prefix> test a Benchmark of <Label>, from the first Control of the test' -ForEach @(
        @{ Prefix = 'CIS.M365.'; Label = 'cis-m365'; Framework = 'cis-m365'; Version = '7.0.0'; Count = 120 }
        @{ Prefix = 'CIS.GH.'; Label = 'cis-github'; Framework = 'cis-github'; Version = '1.2.0'; Count = 5 }
        @{ Prefix = 'CISA.'; Label = 'cisa-scuba'; Framework = 'cisa-scuba'; Version = $null; Count = 79 }
        @{ Prefix = 'ASD.'; Label = 'essential-eight or ism'; Framework = @('essential-eight', 'ism'); Version = $null; Count = 14 }
    ) {
        $tests = @($script:builtIn | Where-Object { $_.Id.StartsWith($Prefix) })
        $tests.Count | Should -Be $Count
        # An ASD test implements an Essential Eight requirement, or an ISM control outside the maturity model.
        @($tests | Where-Object { -not $_.Benchmark -or $_.Benchmark.Framework -cnotin @($Framework) } | ForEach-Object Id) | Should -BeNullOrEmpty
        if ($Version) { @($tests | Where-Object { $_.Benchmark.Version -cne $Version } | ForEach-Object Id) | Should -BeNullOrEmpty }
        @($tests | Where-Object { -not $_.Benchmark.Version } | ForEach-Object Id) | Should -BeNullOrEmpty
        # The requirement a built-in test implements is the rest of its ID after the prefix.
        @($tests | Where-Object { "$Prefix$($_.Benchmark.Requirement)" -cne $_.Id } | ForEach-Object Id) | Should -BeNullOrEmpty
        @($tests | Where-Object { @($_.Control)[0] -cne "$($_.Benchmark.Framework):$($_.Benchmark.Requirement)" } | ForEach-Object Id) | Should -BeNullOrEmpty
    }

    It 'Carries Benchmark as null on every other test' {
        $others = @($script:builtIn | Where-Object { $_.Id -notlike 'CIS.*' -and $_.Id -notlike 'CISA.*' -and $_.Id -notlike 'ASD.*' })
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
        $test.Control | Should -Be @('cisa-scuba:MS.AAD.1.1', 'nist-800-53-r5:CM-7')
        $script:byId['CISA.MS.EXO.8.1'].Benchmark.Upstream.Status | Should -Be 'Moved'
        $script:byId['CISA.MS.EXO.8.3'].Benchmark.Upstream.Status | Should -Be 'Removed'

        $cisa = @($script:builtIn | Where-Object { $_.Id -like 'CISA.*' })
        @($cisa | Where-Object { $_.Benchmark.Criticality -cnotin 'SHALL', 'SHOULD' -or $_.Benchmark.Upstream.Status -cnotin 'Current', 'Moved', 'Removed', 'NotFound' } | ForEach-Object Id) | Should -BeNullOrEmpty
        @($cisa | Where-Object { @($_.Control).Count -gt 1 }).Count | Should -Be 71
        @($cisa | ForEach-Object { $_.Control } | Where-Object { $_ -cnotlike 'nist-800-53-r5:*' -and $_ -cnotlike 'cisa-scuba:*' }) | Should -BeNullOrEmpty
    }

    It 'Keeps what the Maester 2.x benchmark tags said about each CIS test' {
        # L1, L2, "CIS E3 Level 1" and "CIS M365 v7.0.0" were tags in 2.x. The framework files are their home now.
        $legacy = InModuleScope Maester { (Get-MtLegacyTagTable).ByTest }
        $versionTag = @{ 'cis-m365' = 'CIS M365 v7.0.0'; 'cis-github' = 'CIS GitHub v1.2.0' }
        $offenders = foreach ($test in ($script:builtIn | Where-Object { $_.Id -like 'CIS.*' })) {
            if (@($test.Benchmark.Profile | Where-Object { $_ -notlike "* Level $($test.Benchmark.Level.Substring(1))" }).Count -gt 0) { "$($test.Id): level $($test.Benchmark.Level) with profiles $($test.Benchmark.Profile -join ', ')" }
            # A test that is new in 3.0 has no 2.x tags to compare with.
            if (-not $legacy.ContainsKey($test.Id)) { continue }
            $tags = @($legacy[$test.Id])
            $level = @($tags | Where-Object { $_ -in 'L1', 'L2' })
            $profiles = @($tags | Where-Object { $_ -match '^CIS .+ Level \d$' } | ForEach-Object { $_ -replace '^CIS ', '' } | Sort-Object)
            if ($level.Count -gt 0 -and $level[0] -ne $test.Benchmark.Level) { "$($test.Id): level $($test.Benchmark.Level), tag $($level[0])" }
            if (($profiles -join '|') -ne (@($test.Benchmark.Profile | Sort-Object) -join '|')) { "$($test.Id): profiles $($test.Benchmark.Profile -join ', '), tags $($profiles -join ', ')" }
            if ($tags -notcontains $versionTag[$test.Benchmark.Framework]) { "$($test.Id): $($test.Benchmark.Framework) $($test.Benchmark.Version) without the tag $($versionTag[$test.Benchmark.Framework])" }
        }
        $offenders | Should -BeNullOrEmpty
    }

    It 'Holds identifiers and facts in the framework files, not the text of a requirement or a list of tests' {
        $offenders = foreach ($file in $script:frameworkFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            foreach ($requirement in $content.Requirements) {
                foreach ($name in $requirement.PSObject.Properties.Name) {
                    if ($name -cnotin 'Id', 'Related', 'Level', 'Profile', 'Criticality', 'Upstream', 'Strategy', 'Guideline', 'Section', 'Applicability') { "$($file.Name): requirement $($requirement.Id) has $name" }
                }
            }
        }
        $offenders | Should -BeNullOrEmpty -Because 'benchmark text is licensed; a requirement is named by its ID, and a test names its requirement in Control'
    }
}

Describe 'Benchmark and Control on result rows' {
    BeforeAll {
        # A custom folder: the fixture suite and one Pester-format test.
        $script:runFolder = Join-Path $TestDrive 'run'
        Copy-Item -LiteralPath (Join-Path $script:valid 'contoso') -Destination $script:runFolder -Recurse
        # Pester-format tests run only from a Custom folder.
        $null = New-Item -ItemType Directory -Path (Join-Path $script:runFolder 'Custom') -Force
        "Describe 'Pester block' { It 'PES.1: pester test' { `$true | Should -BeTrue } }" | Set-Content (Join-Path $script:runFolder 'Custom/Pester.Tests.ps1')

        # Invoke-Maester calls Invoke-Pester, so the runs happen in a child process: all of them in one, for speed.
        # The built-in suites are read without a tenant: -DryRun runs no test, and a row says why its test would
        # not have run (no connection) or that it would have (DryRun).
        $scenarios = [ordered]@{
            Custom = '-SkipBuiltIn'
            Cis    = '-Suite cis -DryRun'
            Cisa   = '-Suite cisa -DryRun'
            Asd    = '-Suite asd -DryRun'
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
        $rows['CONTOSO.BL.1.1'].Control | Should -BeExactly @('contoso-policy:P-12', 'contoso-baseline:1.1', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
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
        $row.Control | Should -Be @('contoso-cloud:NET-7', 'nist-800-53-r5:SC-7', 'nist-800-53-r5:AC-4')

        $baseline = $rows | Where-Object Id -EQ 'CONTOSO.BL.1.10'
        $baseline.Benchmark.Requirement | Should -BeExactly '1.10'
        $baseline.Benchmark.Profile | Should -Be @('Standard', 'Strict')
        ($rows | Where-Object Id -EQ 'CONTOSO.BL.1.1').Control | Should -Be @('contoso-policy:P-12', 'contoso-baseline:1.1', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
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
        $rows.Count | Should -Be 125
        @($rows | Where-Object { $_.Result -notin 'NotRun', 'Skipped' -or $_.ReasonCode -eq 'NotSelected' } | ForEach-Object Id) | Should -BeNullOrEmpty -Because 'the suite is selected and nothing runs'
        @($rows | Where-Object { $_.Benchmark.Framework -cnotin 'cis-m365', 'cis-github' -or $_.Benchmark.Level -cnotin 'L1', 'L2' -or -not $_.Benchmark.Requirement } | ForEach-Object Id) | Should -BeNullOrEmpty
        $row = $rows | Where-Object Id -EQ 'CIS.M365.1.1.1'
        $row.Benchmark.Version | Should -BeExactly '7.0.0'
        $row.Benchmark.Profile | Should -Be @('E3 Level 1')
    }

    It 'Gives the rows of the ASD suite their maturity level and strategy, and the ISM control as Control, without a tenant' {
        $rows = @((Get-Run 'Asd').Tests | Where-Object Suite -EQ 'ASD')
        $rows.Count | Should -Be 14
        @($rows | Where-Object { $_.Benchmark.Framework -cnotin 'essential-eight', 'ism' -or -not $_.Benchmark.Requirement } | ForEach-Object Id) | Should -BeNullOrEmpty
        $essentialEight = @($rows | Where-Object { $_.Benchmark.Framework -ceq 'essential-eight' })
        $essentialEight.Count | Should -Be 13
        @($essentialEight | Where-Object { $_.Benchmark.Level -cnotin 'ML1', 'ML2', 'ML3' -or -not $_.Benchmark.Strategy } | ForEach-Object Id) | Should -BeNullOrEmpty
        # The framework file relates each Essential Eight requirement to the ISM control of the same ID.
        @($essentialEight | Where-Object { $_.Control -cnotcontains "ism:$($_.Benchmark.Requirement)" } | ForEach-Object Id) | Should -BeNullOrEmpty
        $row = $rows | Where-Object Id -EQ 'ASD.ISM-1504'
        $row.Benchmark.Level | Should -BeExactly 'ML1'
        $row.Benchmark.Strategy | Should -BeExactly 'Multi-factor authentication'
        @($row.Control)[0] | Should -BeExactly 'essential-eight:ISM-1504'
        # The Related reference follows the test's own values: the ISM control of the same ID.
        @($row.Control)[-1] | Should -BeExactly 'ism:ISM-1504'
        $ism = $rows | Where-Object Id -EQ 'ASD.ISM-1403'
        $ism.Benchmark.Framework | Should -BeExactly 'ism'
        $ism.Benchmark.Section | Should -BeExactly 'User account lockouts'
        @($ism.Benchmark.Applicability) | Should -Contain 'P'
    }

    It 'Gives the rows of the CISA suite their Benchmark and the NIST SP 800-53 controls without a tenant' {
        $run = Get-Run 'Cisa'
        $rows = @($run.Tests | Where-Object Suite -EQ 'CISA')
        $rows.Count | Should -Be 79
        @($rows | Where-Object { $_.Benchmark.Framework -cne 'cisa-scuba' -or -not $_.Benchmark.Criticality } | ForEach-Object Id) | Should -BeNullOrEmpty
        @($rows | Where-Object { @($_.Control).Count -gt 1 }).Count | Should -Be 71
        $row = $rows | Where-Object Id -EQ 'CISA.MS.AAD.3.1'
        $row.Benchmark.Requirement | Should -BeExactly 'MS.AAD.3.1'
        $row.Benchmark.Upstream.Id | Should -Be 'MS.AAD.3.1v1'
        $row.Control | Should -Be @('cisa-scuba:MS.AAD.3.1', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-2(2)', 'nist-800-53-r5:IA-5c', 'nist-800-53-r5:IA-5g', 'nist-800-53-r5:IA-2(8)')
        # A test of another suite is in the result too, not selected, and has no Benchmark.
        $other = $run.Tests | Where-Object Id -EQ 'MT.1001'
        $other.ReasonCode | Should -Be 'NotSelected'
        $other.PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty
        $other.Benchmark | Should -BeNullOrEmpty
    }
}

Describe 'A custom suite with a framework problem' {
    It 'Warns about <Case> and takes no Benchmark from the framework' -ForEach @(
        @{ Case = 'a framework without a file'; Folder = 'missing-file'; Id = 'FXM.1'; Control = 'fx-missing:R1'; Message = "Ignoring the framework 'fx-missing' of *suite.json*, so no test gets a Benchmark from it. *fx-missing.json: the file does not exist.*" }
        @{ Case = 'a file that names another key'; Folder = 'wrong-key'; Id = 'FXK.1'; Control = 'fx-key:R1'; Message = "Ignoring the framework 'fx-key' of *fx-key.json: Framework is 'fx-other'; the suite.json declares the key 'fx-key'.*" }
        @{ Case = 'a Related reference that is not a control'; Folder = 'bad-related'; Id = 'FXR.1'; Control = 'fx-related:R1'; Message = "Ignoring the framework 'fx-related' of *fx-related.json: the requirement R1 has the Related reference 'NIST-800-53-R5:IA-3', which is not written <framework-key>:<control-id>*" }
    ) {
        $read = Read-Suite (Join-Path $script:invalid $Folder)
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike $Message
        $read.Tests[$Id].IsValid | Should -BeTrue -Because 'the test itself is fine'
        $read.Tests[$Id].PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty
        $read.Tests[$Id].Benchmark | Should -BeNullOrEmpty
        $read.Tests[$Id].Control | Should -BeExactly @($Control) -Because 'the Control of the test is kept, and nothing is added to it'
    }

    It 'Says in the warning that the file and the suite.json disagree about the version' {
        (Read-Suite (Join-Path $script:invalid 'wrong-key')).Warnings[0] | Should -BeLike "*fx-key.json: Version is '2.0'; the suite.json declares the version '1.0'.*"
    }

    It 'Warns once about a file that is not valid JSON, whatever the number of tests' {
        $folder = Join-Path $TestDrive 'bad-json'
        Copy-Item -LiteralPath (Join-Path $script:invalid 'unknown-requirement') -Destination $folder -Recurse
        '{ "Framework": "fx-unknown", ' | Set-Content (Join-Path $folder 'frameworks/fx-unknown.json')
        $read = Read-Suite $folder
        $read.Tests.Count | Should -Be 2
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike "Ignoring the framework 'fx-unknown' of *fx-unknown.json: it is not valid JSON."
        @($read.Tests.Values | Where-Object { $null -ne $_.Benchmark }) | Should -HaveCount 0
    }

    It 'Warns about a Control that names a requirement the file does not have, and keeps the Benchmark of the other tests' {
        $read = Read-Suite (Join-Path $script:invalid 'unknown-requirement')
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike "These tests have a Control that names the framework 'fx-unknown' and a requirement that '*fx-unknown.json' does not have, so it gives them no Benchmark: FXU.2 (fx-unknown:R9)."
        $read.Tests['FXU.1'].Benchmark.Requirement | Should -Be 'R1'
        $read.Tests['FXU.2'].IsValid | Should -BeTrue
        $read.Tests['FXU.2'].Benchmark | Should -BeNullOrEmpty
        $read.Tests['FXU.2'].Control | Should -BeExactly @('fx-unknown:R9')
    }

    It 'Warns about a key that two suites declare and uses the framework of the first' {
        $read = Read-Suite (Join-Path $script:invalid 'same-key')
        $read.Warnings | Should -HaveCount 1
        $read.Warnings[0] | Should -BeLike "*same-key?b?suite.json: the framework 'fx-same' is also declared by '*same-key?a?suite.json'*"
        $read.Tests['FXS.1'].Benchmark.Level | Should -Be 'L1'
    }

    It 'Never stops a run: every test still runs, with or without a Benchmark' {
        $warnings = $null
        $rows = @(Invoke-MtTest -Path $script:invalid -WarningVariable warnings -WarningAction SilentlyContinue 6>$null)
        $rows.Count | Should -Be 6
        @($rows | Where-Object Result -NE 'Passed' | ForEach-Object { "$($_.Id): $($_.Result) $($_.ReasonDetail)" }) | Should -BeNullOrEmpty
        @($rows | Where-Object { $_.Benchmark } | ForEach-Object Id | Sort-Object) | Should -Be @('FXS.1', 'FXU.1')
        @($warnings | Where-Object { $_.Message -like 'Ignoring the framework*' }).Count | Should -Be 3
        @($warnings | Where-Object { $_.Message -like 'These tests have a Control*' }).Count | Should -Be 1
        @($warnings | Where-Object { $_.Message -like '*is also declared by*' }).Count | Should -Be 1
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
            "missing-file/frameworks/fx-missing.json: the file does not exist. The suite.json declares the framework 'fx-missing'."
            "same-key/b/suite.json: the framework 'fx-same' is also declared by '/same-key/a/suite.json'. A framework key is declared by one suite; the first one is used."
            "unknown-requirement/Test.FXU.2.ps1: the test FXU.2 has the Control 'fx-unknown:R9', and '/unknown-requirement/frameworks/fx-unknown.json' has no requirement with that Id."
            "wrong-key/frameworks/fx-key.json: Framework is 'fx-other'; the suite.json declares the key 'fx-key'."
            "wrong-key/frameworks/fx-key.json: Version is '2.0'; the suite.json declares the version '1.0'."
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

    It 'Finds every problem of the framework files and of the Control that names them, and names the file in each message' {
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
        $folder = New-SuiteFolder -Declaration @{ Key = 'contoso'; Version = '1.0' } -File @{ contoso = '{ "Framework": "other", "Requirements": [ { "Id": "R1" } ] }' }
        $problems = @(InModuleScope Maester -Parameters @{ R = $folder } { Get-MtFrameworkProblem -Test @() -Root $R })
        $problems | Should -HaveCount 1
        $problems[0] | Should -BeLike "*contoso.json: Framework is 'other'; the suite.json declares the key 'contoso'."
    }

    It 'Does not check a Control that names a framework no suite under the folder declares' {
        $tests = @(
            [pscustomobject]@{ Id = 'FX.1'; File = 'Test.FX.1.ps1'; Control = @('nist-800-53-r5:AC-404', 'cis-m365:404', 'contoso-baseline:1.1') }
            [pscustomobject]@{ Id = 'FX.2'; File = 'Test.FX.2.ps1'; Control = @('contoso-baseline:404') }
        )
        $problems = @(InModuleScope Maester -Parameters @{ R = $script:valid; T = $tests } { Get-MtFrameworkProblem -Test $T -Root $R })
        $problems | Should -HaveCount 1
        $problems[0] | Should -BeLike "Test.FX.2.ps1: the test FX.2 has the Control 'contoso-baseline:404', and '*contoso-baseline.json' has no requirement with that Id."
    }

    It 'Stops the build with those messages' {
        $build = Invoke-Build -TestsRoot $script:invalid -Name 'invalid'
        $build.ExitCode | Should -Be 1
        $build.Lines[0] | Should -Be 'Built-in native tests have 7 problem(s):' -Because 'the framework files are all that is wrong with the fixture tests'
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
        ($catalog.Tests | Where-Object Id -EQ 'CONTOSO.BL.1.10').Control | Should -Be @('contoso-baseline:1.10')
        @($catalog.Tests).Count | Should -Be 5
        $test = $catalog.Tests | Where-Object Id -EQ 'CONTOSO.BL.1.1'
        $test.Benchmark.Framework | Should -BeExactly 'contoso-baseline'
        $test.Benchmark.Version | Should -BeExactly '2.1'
        $test.Benchmark.Requirement | Should -BeExactly '1.1'
        $test.Benchmark.Profile | Should -Be @('Standard')
        $test.Control | Should -Be @('contoso-policy:P-12', 'contoso-baseline:1.1', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
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
            $object.Control | Should -Be @('contoso-policy:P-12', 'contoso-baseline:1.1', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-5', 'iso-27001:A.5.17')
        }
        @($objects | Where-Object { $_.Result -and $_.Result -ne 'Passed' }) | Should -HaveCount 0
        @($objects | Where-Object { $_.Id -eq 'CONTOSO.OTHER.1' -and $null -ne $_.Benchmark }) | Should -HaveCount 0
        @($objects | Where-Object { $_.Id -eq 'CONTOSO.CLOUD.NET-7' -and $_.Benchmark.Upstream.Id -eq 'NET-9v2' -and (@($_.Control) -join ',') -eq 'contoso-cloud:NET-7,nist-800-53-r5:SC-7,nist-800-53-r5:AC-4' }) | Should -HaveCount 2
    }
}

Describe 'Docs export' {
    BeforeAll {
        # The exporter imports the module, so it runs in a child process.
        $script:exportFile = Join-Path $TestDrive 'test-catalog.json'
        $null = & $script:pwsh -NoProfile -NonInteractive -File (Join-Path $script:repoRoot 'build/docs/Export-MtTestCatalogForDocs.ps1') -OutputPath $script:exportFile 2>&1
        $script:export = Get-Content -LiteralPath $script:exportFile -Raw | ConvertFrom-Json
        $script:exported = @{}
        foreach ($t in $script:export.Tests) { $script:exported[$t.Id] = $t }
    }

    It 'Names every framework the tests use, with its version' {
        @($script:export.Frameworks.Key) | Should -Be @('cis-github', 'cis-m365', 'cisa-scuba', 'essential-eight', 'ism')
        ($script:export.Frameworks | Where-Object Key -EQ 'cis-m365').Name | Should -Be 'CIS Microsoft 365 Foundations Benchmark'
        ($script:export.Frameworks | Where-Object Key -EQ 'cis-m365').Version | Should -BeExactly '7.0.0'
        @($script:export.Tests | Where-Object { $_.Benchmark -and $_.Benchmark.Framework -cnotin $script:export.Frameworks.Key } | ForEach-Object Id) | Should -BeNullOrEmpty
    }

    It 'Carries Benchmark and Control for each test' {
        $cis = $script:exported['CIS.M365.1.1.1']
        $cis.Benchmark.Requirement | Should -BeExactly '1.1.1'
        $cis.Benchmark.Level | Should -Be 'L1'
        $cis.Benchmark.Profile | Should -Be @('E3 Level 1')
        $cisa = $script:exported['CISA.MS.EXO.8.1']
        $cisa.Benchmark.Criticality | Should -Be 'SHALL'
        $cisa.Benchmark.Upstream.Id | Should -Be 'MS.SECURITYSUITE.3.1v1'
        $cisa.Control | Should -Be @('cisa-scuba:MS.EXO.8.1', 'nist-800-53-r5:SC-7(10)')
        $script:exported['MT.1001'].PSObject.Properties['Benchmark'] | Should -Not -BeNullOrEmpty
        $script:exported['MT.1001'].Benchmark | Should -BeNullOrEmpty
        # A reference to a framework without a file, such as NIST SP 800-53, stays in Control and gives no Benchmark.
        @($script:exported['MT.1001'].Control | Where-Object { $_ -notlike 'nist-800-53-r5:*' }).Count | Should -Be 0
        @($script:exported['AD-CFG-02'].Control).Count | Should -Be 0
    }

    It 'Gives the level of every CIS test, which the generated title shows as (L1) or (L2)' {
        $cis = @($script:export.Tests | Where-Object { $_.Id -like 'CIS.*' })
        $cis.Count | Should -Be 125
        @($cis | Where-Object { $_.Benchmark.Level -cnotmatch '^L[12]$' } | ForEach-Object Id) | Should -BeNullOrEmpty
        $generator = Get-Content -LiteralPath (Join-Path $script:repoRoot 'website/scripts/generate-test-docs.mjs') -Raw
        $generator | Should -Match 'test\.Benchmark\?\.Level' -Because 'the title prefix comes from Benchmark'
        $generator | Should -Not -Match 'titleFor\(test, legacyTags\)' -Because 'the title no longer reads the Maester 2.x tags'
    }
}
