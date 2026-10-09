BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
    $script:fixtures = (Resolve-Path "$PSScriptRoot/../../fixtures/error-paths").Path

    function New-NativeTestFile {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([string] $Folder, [string] $Id, [string] $Body = '$true', [string] $Attribute = '', [string] $Param = '', [switch] $NoMarkdown)
        $null = New-Item -ItemType Directory -Path $Folder -Force
        $name = 'Test-' + ($Id -replace '[^A-Za-z0-9]', '')
        $extra = if ($Attribute) { ", $Attribute" } else { '' }
        @"
function $name {
    [MaesterTest(Id = '$Id', Title = 'Title of $Id', Severity = 'High'$extra)]
    [CmdletBinding()]
    param($Param)
    $Body
}
"@ | Set-Content (Join-Path $Folder "Test.$Id.ps1")
        if (-not $NoMarkdown) { "Description of $Id.`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $Folder "Test.$Id.md") }
        Join-Path $Folder "Test.$Id.ps1"
    }
}

Describe 'Read-MtNativeTest' {
    It 'Reads the attribute, function and parameters of a valid test' {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'valid') -Id 'CONTOSO.1' -Attribute "Tag = ('a', 'b'), LongRunning, Service = 'Graph', License = 'AAD_PREMIUM'" -Param @'
        # Days a credential may live.
        [ValidateRange(1, 365)]
        [int] $Days = 30,
        [MaesterParameter(Kind = 'Entra.Group')]
        [string[]] $Groups
'@
        $t = InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }
        $t.Errors | Should -HaveCount 0
        $t.Id | Should -Be 'CONTOSO.1'
        $t.FunctionName | Should -Be 'Test-CONTOSO1'
        $t.Tag | Should -Be @('a', 'b')
        $t.LongRunning | Should -BeTrue
        $t.Service | Should -Be @('Graph')
        $t.License | Should -Be @('AAD_PREMIUM')
        $days = $t.Parameters | Where-Object Name -EQ 'Days'
        $days.Type | Should -Be 'int'
        $days.Default | Should -Be 30
        $days.Range | Should -Be @(1, 365)
        $days.Description | Should -Be 'Days a credential may live.'
        ($t.Parameters | Where-Object Name -EQ 'Groups').Kind | Should -Be 'Entra.Group'
    }

    It 'Reports <Case> as <Code>' -ForEach @(
        @{ Case = 'an unknown property'; Attribute = "Nope = 'x'"; Code = 'InvalidMetadata' }
        @{ Case = 'a value outside the allowed list'; Attribute = "Cloud = 'Mars'"; Code = 'InvalidMetadata' }
        @{ Case = 'a reserved property'; Attribute = "Product = 'x'"; Code = 'InvalidMetadata' }
    ) {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive ("bad" + [guid]::NewGuid().ToString('n'))) -Id 'BAD.1' -Attribute $Attribute
        $t = InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }
        $t.Errors.Code | Should -Contain $Code
    }

    It 'Reports a missing Markdown file for a custom test' {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'nomd') -Id 'NOMD.1' -NoMarkdown
        (InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }).Errors.Message | Should -BeLike '*Markdown*'
    }

    It 'Reports a top-level statement' {
        $folder = Join-Path $TestDrive 'toplevel'
        $file = New-NativeTestFile -Folder $folder -Id 'TOP.1'
        "Write-Host 'side effect'`n" + (Get-Content $file -Raw) | Set-Content $file
        (InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }).Errors.Message | Should -BeLike '*only function definitions*'
    }

    It 'Records an unregistered service of a custom test instead of failing it' {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'unreg') -Id 'UNREG.1' -Attribute "Service = 'ContosoCrm'"
        $t = InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }
        $t.Errors | Should -HaveCount 0
        $t.UnregisteredServices | Should -Be @('ContosoCrm')
    }

    It 'Reads every error-path fixture without errors' {
        foreach ($f in Get-ChildItem $script:fixtures -Filter 'Test.*.ps1') {
            (InModuleScope Maester -Parameters @{ File = $f.FullName } { Read-MtNativeTest -Path $File }).Errors | Should -HaveCount 0 -Because $f.Name
        }
    }
}

Describe 'Parameter binding (appendix A.5)' {
    BeforeAll {
        $script:test = [pscustomobject]@{
            Parameters = @(
                [pscustomobject]@{ Name = 'Days'; Type = 'int'; Default = 30; Range = @(1, 365); AllowedValues = $null; Kind = $null; EngineOwned = $false }
                [pscustomobject]@{ Name = 'Mode'; Type = 'string'; Default = 'A'; Range = $null; AllowedValues = @('A', 'B'); Kind = $null; EngineOwned = $false }
                [pscustomobject]@{ Name = 'Groups'; Type = 'string[]'; Default = $null; Range = $null; AllowedValues = $null; Kind = 'Entra.Group'; EngineOwned = $false }
                [pscustomobject]@{ Name = 'Strict'; Type = 'switch'; Default = $null; Range = $null; AllowedValues = $null; Kind = $null; EngineOwned = $false }
                [pscustomobject]@{ Name = 'Instance'; Type = 'object'; Default = $null; Range = $null; AllowedValues = $null; Kind = $null; EngineOwned = $true }
            )
        }
        function Get-Binding { param($Values) InModuleScope Maester -Parameters @{ T = $script:test; V = $Values } { ConvertTo-MtTestParameter -Test $T -ConfigValue $V } }
    }

    It 'Binds valid values and reports the effective ones with their source' {
        $b = Get-Binding @{ Days = 90; Mode = 'B'; Groups = @(@{ Id = '6f9619ff-8b86-d011-b42d-00c04fc964ff'; DisplayName = 'Finance' }); Strict = $true }
        $b.Error | Should -BeNullOrEmpty
        $b.Bound.Days | Should -Be 90
        $b.Bound.Groups | Should -Be @('6f9619ff-8b86-d011-b42d-00c04fc964ff')
        ($b.Effective | Where-Object Name -EQ 'Days').Source | Should -Be 'Config'
        ($b.Effective | Where-Object Name -EQ 'Mode').Value | Should -Be 'B'
    }

    It 'Rejects <Case>' -ForEach @(
        @{ Case = 'a fraction for an int'; Values = @{ Days = 90.5 } }
        @{ Case = 'a string for an int'; Values = @{ Days = '90' } }
        @{ Case = 'a value outside the range'; Values = @{ Days = 400 } }
        @{ Case = 'a value outside ValidateSet'; Values = @{ Mode = 'C' } }
        @{ Case = 'an unknown parameter'; Values = @{ Nope = 1 } }
        @{ Case = 'an abbreviated name'; Values = @{ Da = 1 } }
        @{ Case = 'a common parameter'; Values = @{ Verbose = $true } }
        @{ Case = 'an engine-owned parameter'; Values = @{ Instance = 'x' } }
        @{ Case = 'a string for a switch'; Values = @{ Strict = 'yes' } }
        @{ Case = 'a malformed object ID for its kind'; Values = @{ Groups = @('not-a-guid') } }
    ) {
        (Get-Binding $Values).Error | Should -Not -BeNullOrEmpty
    }
}

Describe 'Licence requirements' {
    It 'Matches <Requirement> against plans <Plans>: <Expected>' -ForEach @(
        @{ Requirement = @('AAD_PREMIUM'); Plans = @('41781fb2-bc02-4b7c-bd55-b576c07bb09d'); Expected = $true }
        @{ Requirement = @('AAD_PREMIUM'); Plans = @('eec0eb4f-6444-4f95-aba0-50c24d67f998'); Expected = $true }
        @{ Requirement = @('AAD_PREMIUM_P2'); Plans = @('41781fb2-bc02-4b7c-bd55-b576c07bb09d'); Expected = $false }
        @{ Requirement = @('INTUNE_A'); Plans = @('d216f254-796f-4dab-bbfa-710686e646b9'); Expected = $true }
        @{ Requirement = @('AAD_PREMIUM_P2', 'Entra_Identity_Governance'); Plans = @('e866a266-3cff-43a3-acca-0c90a7e00c8b'); Expected = $true }
        @{ Requirement = @('AAD_PREMIUM&INTUNE_A'); Plans = @('41781fb2-bc02-4b7c-bd55-b576c07bb09d'); Expected = $false }
        @{ Requirement = @('AAD_PREMIUM&INTUNE_A'); Plans = @('41781fb2-bc02-4b7c-bd55-b576c07bb09d', 'c1ec4a95-1f05-45b3-a911-aa3fa01094f5'); Expected = $true }
    ) {
        InModuleScope Maester -Parameters @{ R = $Requirement; P = $Plans } {
            Test-MtLicenseRequirement -Requirement $R -Licenses ([pscustomobject]@{ ServicePlanIds = $P; SkuIds = @(); ServicePlanNames = @() })
        } | Should -Be $Expected
    }

    It 'Matches a token that is not in the table literally against plan names' {
        InModuleScope Maester {
            Test-MtLicenseRequirement -Requirement 'CONTOSO_PLAN' -Licenses ([pscustomobject]@{ ServicePlanIds = @(); SkuIds = @(); ServicePlanNames = @('CONTOSO_PLAN') })
        } | Should -BeTrue
    }
}

Describe 'Applicability gates' {
    BeforeAll {
        $script:context = [pscustomobject]@{
            Platform = 'Linux'; TenantType = 'Workforce'; Cloud = 'Commercial'
            Services = [pscustomobject]@{ Graph = $true; ExchangeOnline = $false }
            Licenses = [pscustomobject]@{ State = 'Known'; ServicePlanIds = @(); SkuIds = @(); ServicePlanNames = @() }
        }
        function Get-Gate { param([hashtable] $Test, [hashtable] $Enforce = @{ Service = $true; License = $true; TenantType = $false; Cloud = $false })
            $merged = @{ Platform = @(); TenantType = @(); Cloud = @(); Service = @(); UnregisteredServices = @(); License = @() }
            foreach ($k in $Test.Keys) { $merged[$k] = $Test[$k] }
            $t = [pscustomobject]$merged
            InModuleScope Maester -Parameters @{ T = $t; C = $script:context; E = $Enforce } { Test-MtApplicability -Test $T -TenantContext $C -Enforce $E }
        }
    }

    It 'Skips a test whose service is not connected, with the 2.x skip code' {
        $g = Get-Gate @{ Service = @('ExchangeOnline') }
        $g.ReasonCode | Should -Be 'ServiceNotConnected'
        $g.LegacySkipCode | Should -Be 'NotConnectedExchange'
    }

    It 'Skips a test for another platform' { (Get-Gate @{ Platform = @('Windows') }).ReasonCode | Should -Be 'PlatformMismatch' }
    It 'Skips a test for an unregistered service' { (Get-Gate @{ UnregisteredServices = @('X') }).ReasonCode | Should -Be 'ServiceNotRegistered' }
    It 'Skips a test the tenant is not licensed for' { (Get-Gate @{ License = @('AAD_PREMIUM') }).ReasonCode | Should -Be 'LicenseNotFound' }
    It 'Does not enforce tenant type unless asked' { Get-Gate @{ TenantType = @('External') } | Should -BeNullOrEmpty }
    It 'Enforces tenant type when asked' {
        (Get-Gate @{ TenantType = @('External') } -Enforce @{ Service = $true; License = $true; TenantType = $true; Cloud = $false }).ReasonCode | Should -Be 'TenantTypeMismatch'
    }
    It 'Lets a test run when every gate passes' { Get-Gate @{ Service = @('Graph') } | Should -BeNullOrEmpty }
    It 'Never skips on an unknown licence state' {
        $script:context.Licenses.State = 'Unknown'
        Get-Gate @{ License = @('AAD_PREMIUM') } | Should -BeNullOrEmpty
        $script:context.Licenses.State = 'Known'
    }
}

Describe 'Invoke-MtTest, New-MtTest and Get-MtTest' {
    It 'Scaffolds a test that validates and runs' {
        $folder = Join-Path $TestDrive 'scaffold'
        $null = New-MtTest -Id CONTOSO.1001 -Title 'Example check' -Service None -Path $folder
        "Test.CONTOSO.1001.ps1", "Test.CONTOSO.1001.md" | ForEach-Object { Join-Path $folder $_ | Should -Exist }
        $test = Get-MtTest -Path $folder
        $test.IsValid | Should -BeTrue
        $test.Id | Should -Be 'CONTOSO.1001'
    }

    It 'Runs a custom test from a file with a parameter value and returns its row' {
        $folder = Join-Path $TestDrive 'invoke'
        $file = New-NativeTestFile -Folder $folder -Id 'INV.1' -Attribute "Service = 'None'" -Param '[int] $Limit = 1' -Body 'return ($Limit -eq 5)'
        $row = Invoke-MtTest -Path $file -Parameter @{ Limit = 5 }
        $row.Id | Should -Be 'INV.1'
        $row.Result | Should -Be 'Passed'
        $row.Format | Should -Be 'Native'
        $row.Source | Should -Be 'Custom'
        ($row.Parameters | Where-Object Name -EQ 'Limit').Value | Should -Be 5
    }

    It 'Rejects an invalid parameter value as InvalidConfiguration' {
        $folder = Join-Path $TestDrive 'invoke2'
        $file = New-NativeTestFile -Folder $folder -Id 'INV.2' -Attribute "Service = 'None'" -Param '[ValidateRange(1, 10)] [int] $Limit = 1'
        $row = Invoke-MtTest -Path $file -Parameter @{ Limit = 50 }
        $row.Result | Should -Be 'Error'
        $row.ReasonCode | Should -Be 'InvalidConfiguration'
    }

    It 'Runs the error-path fixtures with the contract outcomes' {
        $expected = (Get-Content (Join-Path $script:fixtures 'expected.json') -Raw | ConvertFrom-Json).fixtures | Where-Object { $_.id -ne 'FIXTURE.0017' }
        $rows = @(Invoke-MtTest -Path $script:fixtures -Id ($expected.id) 6>$null 3>$null)
        foreach ($e in $expected) {
            $row = $rows | Where-Object Id -EQ $e.id
            "$($row.Result)/$($row.ReasonCode)" | Should -Be "$($e.expectedResult)/$($e.expectedReasonCode)" -Because $e.id
        }
    }

    It 'Lists the built-in catalog without a tenant' {
        $all = @(Get-MtTest)
        $all.Count | Should -BeGreaterThan 0
        @($all | Where-Object { -not $_.IsValid }) | Should -HaveCount 0
    }
}

Describe 'Native rows in Invoke-Maester results' {
    BeforeAll {
        $script:folder = Join-Path $TestDrive 'mixed'
        $null = New-Item -ItemType Directory -Path $script:folder -Force
        $null = New-NativeTestFile -Folder $script:folder -Id 'MIX.1' -Attribute "Service = 'None', Category = 'Mixed'"
        $null = New-NativeTestFile -Folder $script:folder -Id 'MIX.2' -Attribute "Service = 'ExchangeOnline', Category = 'Mixed'"
        $null = New-NativeTestFile -Folder $script:folder -Id 'MIX.3' -Attribute "Service = 'None', Category = 'Mixed'" -Body 'throw "broken"'
        "Describe 'Pester' { It 'PES.1: pester test' { `$true | Should -BeTrue } }" | Set-Content (Join-Path $script:folder 'Pester.Tests.ps1')
        $json = Join-Path $TestDrive 'mixed.json'
        $xml = Join-Path $TestDrive 'mixed.xml'
        $manifest = (Resolve-Path "$PSScriptRoot/../../../Maester.psd1").Path
        $null = pwsh -NoProfile -NonInteractive -Command "Import-Module '$manifest' -WarningAction SilentlyContinue; `$null = Invoke-Maester -Path '$script:folder' -SkipBuiltIn -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputJsonFile '$json' -WarningAction SilentlyContinue -Config @{ Output = @{ TestResult = @{ Path = '$xml'; Format = 'JUnitXml' } } }" 2>&1
        $script:result = Get-Content $json -Raw | ConvertFrom-Json
        $script:xmlPath = $xml
    }

    It 'Merges native and Pester rows into one result' {
        ($script:result.Tests | Where-Object Id -EQ 'MIX.1').Result | Should -Be 'Passed'
        ($script:result.Tests | Where-Object Id -EQ 'PES.1').Result | Should -Be 'Passed'
        ($script:result.Tests | Where-Object Id -EQ 'PES.1').Format | Should -Be 'Pester'
        $script:result.TotalCount | Should -Be 4
    }

    It 'Skips a native test whose service is not connected' {
        $row = $script:result.Tests | Where-Object Id -EQ 'MIX.2'
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'ServiceNotConnected'
        $row.ResultDetail.TestSkipped | Should -Be 'NotConnectedExchange'
    }

    It 'Reports an uncaught error as Error/TestError without failing the run' {
        ($script:result.Tests | Where-Object Id -EQ 'MIX.3').ReasonCode | Should -Be 'TestError'
        $script:result.Result | Should -Be 'Passed'
    }

    It 'Writes one JUnit file for native and Pester rows, with test errors ignored' {
        [xml]$doc = Get-Content $script:xmlPath -Raw
        $cases = $doc.testsuites.testsuite.testcase
        @($cases).Count | Should -Be 4
        ($cases | Where-Object name -Like '*MIX.3*').skipped | Should -Not -BeNullOrEmpty
    }

    It 'Synthesises one TestSettings row per test in the result config' {
        @($script:result.MaesterConfig.TestSettings | Where-Object Id -EQ 'MIX.1').Count | Should -Be 1
    }
}
