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
        @{ Case = 'a reserved property'; Attribute = "OptionalService = 'x'"; Code = 'InvalidMetadata' }
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

Describe 'Parameters bound to a setting' {
    BeforeAll {
        $script:bound = [pscustomobject]@{
            Parameters = @(
                [pscustomobject]@{ Name = 'ParkedDomains'; Type = 'string[]'; Default = @(); Range = $null; AllowedValues = $null; Kind = 'Entra.Domain'; Setting = 'ParkedDomains'; EngineOwned = $false }
                [pscustomobject]@{ Name = 'EmergencyAccessAccounts'; Type = 'object[]'; Default = @(); Range = $null; AllowedValues = $null; Kind = $null; Setting = 'EmergencyAccessAccounts'; EngineOwned = $false }
                [pscustomobject]@{ Name = 'PolicyFiltering'; Type = 'string'; Default = 'OnlyAssigned'; Range = $null; AllowedValues = @('All', 'OnlyAssigned'); Kind = $null; Setting = 'DefenderEndpointPolicyFiltering'; EngineOwned = $false }
            )
        }
        function Get-SettingBinding {
            param($Config, $Override, $Global)
            InModuleScope Maester -Parameters @{ T = $script:bound; C = $Config; O = $Override; G = $Global } { ConvertTo-MtTestParameter -Test $T -ConfigValue $C -Override $O -GlobalSetting $G }
        }
        function Get-Source { param($Binding, $Name) ($Binding.Effective | Where-Object Name -EQ $Name).Source }
    }

    It 'Binds a parameter from GlobalSettings and records the source and setting' {
        $b = Get-SettingBinding -Global ([pscustomobject]@{ ParkedDomains = @('contoso-old.com'); DefenderEndpointPolicyFiltering = 'All' })
        $b.Error | Should -BeNullOrEmpty
        $b.Bound.ParkedDomains | Should -Be @('contoso-old.com')
        $b.Bound.PolicyFiltering | Should -Be 'All'
        Get-Source $b 'ParkedDomains' | Should -Be 'Setting'
        ($b.Effective | Where-Object Name -EQ 'PolicyFiltering').Setting | Should -Be 'DefenderEndpointPolicyFiltering'
    }

    It 'Lets the test''s TestSettings row override the setting' {
        $b = Get-SettingBinding -Config @{ ParkedDomains = @() } -Global @{ ParkedDomains = @('contoso-old.com') }
        $b.Bound.ParkedDomains | Should -HaveCount 0
        Get-Source $b 'ParkedDomains' | Should -Be 'Config'
    }

    It 'Lets the run''s -Parameter value override the row and the setting' {
        $b = Get-SettingBinding -Config @{ PolicyFiltering = 'OnlyAssigned' } -Override @{ PolicyFiltering = 'All' } -Global @{ DefenderEndpointPolicyFiltering = 'OnlyAssigned' }
        $b.Bound.PolicyFiltering | Should -Be 'All'
        Get-Source $b 'PolicyFiltering' | Should -Be 'Parameter'
    }

    It 'Keeps the default when the setting is not set or is null' {
        $b = Get-SettingBinding -Global @{ ParkedDomains = $null }
        $b.Bound.ContainsKey('ParkedDomains') | Should -BeFalse
        Get-Source $b 'ParkedDomains' | Should -Be 'Default'
    }

    It 'Binds a list of objects' {
        $b = Get-SettingBinding -Global @{ EmergencyAccessAccounts = @(@{ Id = '00000000-0000-0000-0000-0000000000b1'; Type = 'Group' }, [pscustomobject]@{ UserPrincipalName = 'bg@contoso.com' }) }
        $b.Error | Should -BeNullOrEmpty
        $b.Bound.EmergencyAccessAccounts | Should -HaveCount 2
        $b.Bound.EmergencyAccessAccounts[0].Type | Should -Be 'Group'
        $b.Bound.EmergencyAccessAccounts[1].UserPrincipalName | Should -Be 'bg@contoso.com'
    }

    It 'Rejects a setting value that does not fit the parameter: <Case>' -ForEach @(
        @{ Case = 'outside ValidateSet'; Global = @{ DefenderEndpointPolicyFiltering = 'Some' } }
        @{ Case = 'not a domain'; Global = @{ ParkedDomains = @('not a domain') } }
        @{ Case = 'strings for a list of objects'; Global = @{ EmergencyAccessAccounts = @('bg@contoso.com') } }
    ) {
        (Get-SettingBinding -Global $Global).Error | Should -BeLike "Setting '*"
    }

    It 'Reads Setting and takes the kind from the settings registry' {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'setting') -Id 'SET.1' -Param @'
        [MaesterParameter(Setting = 'ParkedDomains')]
        [string[]] $ParkedDomains = @()
'@
        $t = InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }
        $t.Errors | Should -HaveCount 0
        $t.Parameters[0].Setting | Should -Be 'ParkedDomains'
        $t.Parameters[0].Kind | Should -Be 'Entra.Domain'
    }

    It 'Reports <Case>' -ForEach @(
        @{ Case = 'an unregistered setting'; Param = "[MaesterParameter(Setting = 'NoSuchSetting')] [string[]] `$Domains = @()"; Message = '*not a registered setting*' }
        @{ Case = 'a type that differs from the setting'; Param = "[MaesterParameter(Setting = 'ParkedDomains')] [string] `$ParkedDomains = ''"; Message = '*is a string`[`]*' }
        @{ Case = 'a kind that differs from the setting'; Param = "[MaesterParameter(Kind = 'Entra.Group', Setting = 'ParkedDomains')] [string[]] `$ParkedDomains = @()"; Message = '*has kind Entra.Domain*' }
        @{ Case = 'a list of objects without a setting'; Param = '[object[]] $Accounts = @()'; Message = '*only for a parameter bound to a setting*' }
    ) {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive ('bad' + [guid]::NewGuid().ToString('n'))) -Id 'BAD.1' -Param $Param
        (InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }).Errors.Message | Should -BeLike $Message
    }

    It 'Accepts a pack''s own Namespace.Key setting' {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'packsetting') -Id 'PACK.1' -Param "[MaesterParameter(Setting = 'Contoso.Regions')] [string[]] `$Regions = @()"
        (InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }).Errors | Should -HaveCount 0
    }
}

Describe 'GlobalSettings checked against the settings registry' {
    BeforeAll {
        function Test-Setting { param($Global) InModuleScope Maester -Parameters @{ G = $Global } { Test-MtGlobalSetting -GlobalSetting $G } }
    }

    It 'Accepts the shipped config and valid values' {
        $check = Test-Setting ([pscustomobject]@{
                EmergencyAccessAccounts = @(@{ UserPrincipalName = 'bg@contoso.com'; Type = 'user' }, [pscustomobject]@{ Id = '00000000-0000-0000-0000-0000000000b1'; Type = 'Group' })
                ParkedDomains = @('contoso-old.com'); DefenderEndpointPolicyFiltering = 'All'; GitHubOrganization = ''
                XspmExternalDataUris = @{ MicrosoftApps = 'https://contoso.com/apps.json' }; DataverseEnvironmentUrl = $null
            })
        $check.Errors | Should -BeNullOrEmpty
        $check.Warnings | Should -BeNullOrEmpty
        (Test-Setting $null).Errors | Should -BeNullOrEmpty
    }

    It 'Reports <Case>' -ForEach @(
        @{ Case = 'a value of the wrong type'; Global = @{ ParkedDomains = 5 }; Message = 'GlobalSettings.ParkedDomains: expected a string*' }
        @{ Case = 'a value that is not allowed'; Global = @{ DefenderEndpointComplianceLogic = 'Some' }; Message = "*'Some' is not one of EffectivePolicy*" }
        @{ Case = 'a value that does not fit the kind'; Global = @{ ParkedDomains = @('not a domain') }; Message = '*not a valid Entra.Domain*' }
        @{ Case = 'a list item without an identifier'; Global = @{ EmergencyAccessAccounts = @(@{ Type = 'User' }) }; Message = '*item 1: needs Id or UserPrincipalName*' }
        @{ Case = 'a list item with a value that is not allowed'; Global = @{ EmergencyAccessAccounts = @(@{ Id = 'x'; Type = 'Robot' }) }; Message = "*Type 'Robot' is not one of User, Group*" }
        @{ Case = 'a string where an object is expected'; Global = @{ XspmExternalDataUris = 'https://contoso.com' }; Message = '*XspmExternalDataUris: expected an object*' }
    ) {
        (Test-Setting $Global).Errors | Should -BeLike $Message
    }

    It 'Warns about a mistyped key and names the setting it is closest to' {
        $check = Test-Setting @{ ParkedDomain = @('contoso-old.com') }
        $check.Errors | Should -BeNullOrEmpty
        $check.Warnings | Should -BeLike "*'ParkedDomain'*Did you mean 'ParkedDomains'?*"
    }

    It 'Warns about an unknown key without a dot, and about an unknown property of a list item' {
        (Test-Setting @{ MyOwnThing = 1 }).Warnings | Should -BeLike "*'MyOwnThing'*Namespace.Key*"
        (Test-Setting @{ EmergencyAccessAccounts = @(@{ Id = 'x'; Note = 'y' }) }).Warnings | Should -BeLike "*'Note' is ignored*"
    }

    It 'Passes a Namespace.Key that no pack declares' {
        $check = Test-Setting @{ 'Contoso.Regions' = 5 }
        $check.Errors | Should -BeNullOrEmpty
        $check.Warnings | Should -BeNullOrEmpty
    }

    It 'Stops a run that has an invalid setting' {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'badsetting') -Id 'SET.2'
        { Invoke-MtTest -Path $file -Config @{ GlobalSettings = @{ DefenderEndpointPolicyFiltering = 'Some' } } 6>$null } | Should -Throw '*1 invalid setting*DefenderEndpointPolicyFiltering*'
    }
}

Describe 'Settings a pack declares' {
    BeforeAll {
        function Register-PackSetting {
            param([hashtable] $Settings)
            InModuleScope Maester -Parameters @{ S = $Settings } {
                $manifest = [pscustomobject]@{ Connectors = @(); Settings = ($S | ConvertTo-Json -Depth 5 | ConvertFrom-Json) }
                $null = Register-MtPackService -PackSet @([pscustomobject]@{ Id = 'contoso.sample'; Status = 'Ready'; Manifest = $manifest })
            }
        }
    }
    AfterEach { InModuleScope Maester { $null = Register-MtPackService -PackSet @() } }

    It 'Checks the config against them and returns their defaults' {
        Register-PackSetting @{ 'Contoso.Regions' = @{ Type = 'string[]'; Default = @('eu'); AllowedValues = @('eu', 'us') }; 'Contoso.Limit' = @{ Type = 'int' } }
        InModuleScope Maester {
            (Test-MtGlobalSetting -GlobalSetting @{ 'Contoso.Regions' = @('asia') }).Errors | Should -BeLike "*'asia' is not one of eu, us*"
            (Test-MtGlobalSetting -GlobalSetting @{ 'Contoso.Limit' = 'ten' }).Errors | Should -BeLike '*Contoso.Limit: expected a whole number*'
            Get-MtSetting -Name 'Contoso.Regions' | Should -Be @('eu')
            Get-MtSetting -Name 'Contoso.Limit' -Default 3 | Should -Be 3
        }
    }

    It 'Forgets them when the pack is no longer in the run' {
        Register-PackSetting @{ 'Contoso.Limit' = @{ Type = 'int' } }
        InModuleScope Maester {
            $null = Register-MtPackService -PackSet @()
            (Test-MtGlobalSetting -GlobalSetting @{ 'Contoso.Limit' = 'ten' }).Errors | Should -BeNullOrEmpty
        }
    }

    It 'Checks the type of a test parameter bound to one' {
        Register-PackSetting @{ 'Contoso.Regions' = @{ Type = 'string[]' } }
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'packtype') -Id 'PACK.2' -Param "[MaesterParameter(Setting = 'Contoso.Regions')] [string] `$Regions = ''"
        (InModuleScope Maester -Parameters @{ File = $file } { Read-MtNativeTest -Path $File }).Errors.Message | Should -BeLike '*is a string`[`]*'
    }

    It 'Redacts a sensitive setting in the recorded parameters and config, and gives the test the value' {
        Register-PackSetting @{ 'Contoso.ApiKey' = @{ Type = 'string'; Sensitive = $true } }
        InModuleScope Maester {
            $test = [pscustomobject]@{ Parameters = @([pscustomobject]@{ Name = 'ApiKey'; Type = 'string'; Default = ''; Range = $null; AllowedValues = $null; Kind = $null; Setting = 'Contoso.ApiKey'; EngineOwned = $false }) }
            $fromSetting = ConvertTo-MtTestParameter -Test $test -GlobalSetting @{ 'Contoso.ApiKey' = 'secret' }
            $fromSetting.Bound.ApiKey | Should -Be 'secret'
            $fromSetting.Effective[0].Value | Should -Be '[redacted]'
            $fromSetting.Effective[0].Source | Should -Be 'Setting'
            (ConvertTo-MtTestParameter -Test $test -ConfigValue @{ ApiKey = 'row' }).Effective[0].Value | Should -Be '[redacted]'
            (ConvertTo-MtTestParameter -Test $test).Effective[0].Value | Should -Be ''

            $runConfig = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ 'Contoso.ApiKey' = 'secret'; ParkedDomains = @('contoso-old.com') }; TestSettings = @() }
            $recorded = New-MtResultConfig -RunConfig $runConfig
            $recorded.GlobalSettings.'Contoso.ApiKey' | Should -Be '[redacted]'
            $recorded.GlobalSettings.ParkedDomains | Should -Be @('contoso-old.com')
            $runConfig.GlobalSettings.'Contoso.ApiKey' | Should -Be 'secret'
        }
    }
}

Describe 'New-MtTest -Setting' {
    It 'Writes a parameter bound to each setting, with the type, default and allowed values of the registry' {
        $folder = Join-Path $TestDrive 'scaffold-setting'
        $null = New-MtTest -Id CONTOSO.2001 -Title 'Example check' -Service None -Setting EmergencyAccessAccounts, parkeddomains, DefenderEndpointComplianceLogic -Path $folder
        $text = Get-Content (Join-Path $folder 'Test.CONTOSO.2001.ps1') -Raw
        $text | Should -Match "\[ValidateSet\('EffectivePolicy', 'AllPolicies', 'AnyPolicy'\)\]\s+\[string\] \`$DefenderEndpointComplianceLogic = 'EffectivePolicy'"
        $test = Get-MtTest -Path $folder
        $test.IsValid | Should -BeTrue
        $test.Parameters.Name | Should -Be @('EmergencyAccessAccounts', 'ParkedDomains', 'DefenderEndpointComplianceLogic')
        $test.Parameters.Setting | Should -Be @('EmergencyAccessAccounts', 'ParkedDomains', 'DefenderEndpointComplianceLogic')
        $test.Parameters.Type | Should -Be @('object[]', 'string[]', 'string')
        ($test.Parameters | Where-Object Name -EQ 'ParkedDomains').Kind | Should -Be 'Entra.Domain'
        @($test.Parameters | Where-Object { -not $_.Description }) | Should -HaveCount 0
    }

    It 'Refuses <Case> and writes no file' -ForEach @(
        @{ Case = 'a setting that is not registered'; Setting = 'NoSuchSetting'; Message = '*not a registered setting*' }
        @{ Case = 'a connection setting'; Setting = 'GitHubOrganization'; Message = '*connection setting*' }
        @{ Case = 'a setting a parameter cannot hold'; Setting = 'XspmExternalDataUris'; Message = '*connection setting*' }
    ) {
        $folder = Join-Path $TestDrive ('scaffold-bad-' + [guid]::NewGuid().ToString('n'))
        $null = New-MtTest -Id CONTOSO.2002 -Title 'Example check' -Service None -Setting $Setting -Path $folder -ErrorVariable problems -ErrorAction SilentlyContinue
        "$problems" | Should -BeLike $Message
        Test-Path (Join-Path $folder 'Test.CONTOSO.2002.ps1') | Should -BeFalse
    }
}

Describe 'Settings a test reads while it runs' {
    It 'Records the settings read with Get-MtSetting on the result' {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'reads') -Id 'READ.1' -Body "`$null = Get-MtSetting -Name 'GitHubOrganization'; `$null = Get-MtSetting 'Contoso.Regions' -Default @(); `$null = Get-MtSetting -Name 'GitHubOrganization'; `$true"
        $row = Invoke-MtTest -Path $file -Config @{} 6>$null
        $row.SettingsRead | Should -Be @('Contoso.Regions', 'GitHubOrganization')
    }

    It 'Records nothing for a test that reads no setting, or outside a test' {
        $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'noreads') -Id 'READ.2'
        (Invoke-MtTest -Path $file -Config @{} 6>$null).SettingsRead | Should -HaveCount 0
        InModuleScope Maester {
            $before = @($__MtSession.SettingRead.Keys).Count
            $null = Get-MtSetting -Name 'GitHubOrganization'
            @($__MtSession.SettingRead.Keys).Count | Should -Be $before
        }
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

    Context 'Admin portal URLs' {
        BeforeAll {
            $script:savedPortalUrl = InModuleScope Maester { $__MtSession.AdminPortalUrl }
            # The test lists one group, so its result holds a link to that group in the Entra admin center.
            $script:groupBody = 'Add-MtTestResultDetail -Result ''%TestResult%'' -GraphObjects @([pscustomobject]@{ id = ''g1''; displayName = ''Group 1'' }) -GraphObjectType Groups; $true'
            $script:groupLink = '#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/g1)'
        }
        AfterAll { InModuleScope Maester -Parameters @{ Saved = $script:savedPortalUrl } { param($Saved) $__MtSession.AdminPortalUrl = $Saved } }

        It 'Builds absolute links when no run has set the URLs' {
            Mock -ModuleName Maester Get-MgContext { return $null }
            InModuleScope Maester { $__MtSession.AdminPortalUrl = @{} }
            $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'portal') -Id 'INV.3' -Attribute "Service = 'None'" -Body $script:groupBody
            $row = Invoke-MtTest -Path $file
            $row.ResultDetail.TestResult | Should -BeLike "*(https://entra.microsoft.com/$script:groupLink*"
            InModuleScope Maester { $__MtSession.AdminPortalUrl.Entra } | Should -BeNullOrEmpty
        }

        It 'Uses the current connection, then restores the URLs that a run has set' {
            Mock -ModuleName Maester Get-MgContext { return $null }
            InModuleScope Maester { $__MtSession.AdminPortalUrl = @{ Entra = 'https://entra.microsoft.us/' } }
            $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'portal-run') -Id 'INV.4' -Attribute "Service = 'None'" -Body $script:groupBody
            $row = Invoke-MtTest -Path $file
            $row.ResultDetail.TestResult | Should -BeLike "*(https://entra.microsoft.com/$script:groupLink*"
            InModuleScope Maester { $__MtSession.AdminPortalUrl.Entra } | Should -Be 'https://entra.microsoft.us/'
        }

        It 'Runs the tests with relative links when the URLs cannot be set' {
            Mock -ModuleName Maester Get-MgContext { return $null }
            Mock -ModuleName Maester Get-MtAdminPortalUrl { throw "Cannot validate argument on parameter 'Environment'." }
            InModuleScope Maester { $__MtSession.AdminPortalUrl = @{ Entra = 'https://entra.microsoft.us/' } }
            $file = New-NativeTestFile -Folder (Join-Path $TestDrive 'portal-unknown') -Id 'INV.5' -Attribute "Service = 'None'" -Body $script:groupBody
            $row = Invoke-MtTest -Path $file
            $row.Result | Should -Be 'Passed'
            $row.ResultDetail.TestResult | Should -BeLike "*($script:groupLink*"
            InModuleScope Maester { $__MtSession.AdminPortalUrl.Entra } | Should -Be 'https://entra.microsoft.us/'
        }
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
        $script:folder = Join-Path $TestDrive 'mixed/Custom'
        $null = New-Item -ItemType Directory -Path $script:folder -Force
        $null = New-NativeTestFile -Folder $script:folder -Id 'MIX.1' -Attribute "Service = 'None', Feature = 'Mixed'"
        $null = New-NativeTestFile -Folder $script:folder -Id 'MIX.2' -Attribute "Service = 'ExchangeOnline', Feature = 'Mixed'"
        $null = New-NativeTestFile -Folder $script:folder -Id 'MIX.3' -Attribute "Service = 'None', Feature = 'Mixed'" -Body 'throw "broken"'
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
