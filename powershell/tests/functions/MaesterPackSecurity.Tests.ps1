BeforeAll {
    # Exercise the real shared boundaries without importing tenant connections or the built-in test catalogue.
    foreach ($SourceFile in @('Get-MtPackDigest', 'Expand-MtPackArchive', 'Get-MtPackPolicy', 'Get-MtPackBlocklist', 'Resolve-MtPackGitHubSource', 'Invoke-MtPackGitHubRequest', 'Get-MtPackHome', 'Read-MtPackManifest')) {
        . "$PSScriptRoot/../../internal/packs/$SourceFile.ps1"
    }
}

Describe 'Pack security: executable digest' {
    BeforeEach {
        $Pack = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        $null = New-Item -Path $Pack -ItemType Directory
        $script:File = Join-Path $Pack 'helper.ps1'
    }

    It 'hashes executable changes after marker text in <Kind>' -ForEach @(
        @{ Kind = 'a string'; Text = "function Get-Value { `$Marker = '# SIG # Begin signature block'; 'before' }" }
        @{ Kind = 'a here-string'; Text = "function Get-Value { `$Marker = @'`n# SIG # Begin signature block`n# MIIabc`n# SIG # End signature block`n'@`n'before'`n}" }
        @{ Kind = 'a block comment'; Text = "<#`n# SIG # Begin signature block`n# MIIabc`n# SIG # End signature block`n#>`nfunction Get-Value { 'before' }" }
        @{ Kind = 'an incomplete trailer'; Text = "function Get-Value { 'before' }`n# SIG # Begin signature block`n# MIIabc" }
        @{ Kind = 'a completed trailer with executable suffix'; Text = "# SIG # Begin signature block`n# MIIabc`n# SIG # End signature block`nfunction Get-Value { 'before' }" }
    ) {
        [System.IO.File]::WriteAllText($File, $Text)
        $Before = (Get-MtPackDigest -Path $Pack).Digest
        [System.IO.File]::WriteAllText($File, $Text.Replace('before', 'after'))
        (Get-MtPackDigest -Path $Pack).Digest | Should -Not -Be $Before
    }

    It 'does not strip a terminal marker inside an unterminated <Kind>' -ForEach @(
        @{ Kind = 'here-string'; Prefix = "`$Text = @'`n" }
        @{ Kind = 'block comment'; Prefix = "<#`n" }
    ) {
        $Text = $Prefix + "# SIG # Begin signature block`n# MIIabc`n# SIG # End signature block"
        [System.IO.File]::WriteAllText($File, $Text)
        $Before = (Get-MtPackDigest -Path $Pack).Digest
        [System.IO.File]::WriteAllText($File, $Text.Replace('MIIabc', 'MIIdef'))
        (Get-MtPackDigest -Path $Pack).Digest | Should -Not -Be $Before
    }

    It 'preserves signing normalization with <Label> line endings' -ForEach @(
        @{ Label = 'LF'; NewLine = "`n" }
        @{ Label = 'CRLF'; NewLine = "`r`n" }
    ) {
        $Text = "function Get-Value { 'approved' }$NewLine"
        [System.IO.File]::WriteAllText($File, $Text)
        $Before = (Get-MtPackDigest -Path $Pack).Digest
        $Signature = @('# SIG # Begin signature block', '# MIIabc', '# SIG # End signature block') -join $NewLine
        [System.IO.File]::AppendAllText($File, "$NewLine$Signature$NewLine")
        (Get-MtPackDigest -Path $Pack).Digest | Should -Be $Before
        [System.IO.File]::WriteAllText($File, ($Text.Replace('approved', 'changed') + "$NewLine$Signature$NewLine"))
        (Get-MtPackDigest -Path $Pack).Digest | Should -Not -Be $Before
    }

    It 'preserves the portable unsigned file digest' {
        [System.IO.File]::WriteAllText($File, 'ordinary content')
        $FileHash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.IO.File]::ReadAllBytes($File))).ToLowerInvariant()
        $Expected = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes("helper.ps1`t$FileHash`n"))).ToLowerInvariant()
        (Get-MtPackDigest -Path $Pack).Digest | Should -Be "sha256:$Expected"
    }

    It 'refuses an alternate stream on <Location>' -Skip:(-not $IsWindows) -ForEach @(
        @{ Location = 'a file'; Stream = 'payload' }
        @{ Location = 'a directory'; Stream = 'payload' }
        @{ Location = 'the root'; Stream = 'payload' }
        @{ Location = 'a file'; Stream = 'Zone.Identifier' }
    ) {
        [System.IO.File]::WriteAllText($File, 'approved')
        $null = Get-MtPackDigest -Path $Pack
        $Target = switch ($Location) {
            'a file' { $File }
            'a directory' { (New-Item -Path (Join-Path $Pack 'nested') -ItemType Directory).FullName }
            'the root' { $Pack }
        }
        Set-Content -LiteralPath $Target -Stream $Stream -Value 'unapproved'
        { Get-MtPackDigest -Path $Pack } | Should -Throw '*alternate data stream*'
    }
}

Describe 'Pack security: archive paths' {
    BeforeAll {
        function New-PackSecurityArchive {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates disposable archive fixtures under Pester TestDrive only.')]
            [CmdletBinding()]
            param([string] $Path, [string[]] $Entry)
            $Zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
            try {
                foreach ($Name in $Entry) {
                    $Writer = [System.IO.StreamWriter]::new($Zip.CreateEntry($Name).Open())
                    try { $Writer.Write('content') } finally { $Writer.Dispose() }
                }
            } finally { $Zip.Dispose() }
        }
    }

    It 'refuses <Entry> before writing any extracted files' -ForEach @(
        @{ Entry = 'root/a.txt:payload' }
        @{ Entry = 'root/a.txt:payload:$DATA' }
        @{ Entry = 'root/nested:payload/a.txt' }
        @{ Entry = 'root\nested\a.txt:payload' }
    ) {
        $Archive = Join-Path $TestDrive "$([guid]::NewGuid()).zip"
        $Destination = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        New-PackSecurityArchive -Path $Archive -Entry @('root/ordinary.txt', $Entry)
        { Expand-MtPackArchive -Archive $Archive -Destination $Destination } | Should -Throw '*unsafe path*'
        Test-Path -LiteralPath $Destination | Should -BeFalse
    }

    It 'extracts ordinary nested files and retains their content' {
        $Archive = Join-Path $TestDrive 'ordinary.zip'
        $Destination = Join-Path $TestDrive 'ordinary'
        New-PackSecurityArchive -Path $Archive -Entry @('root/nested/a.txt')
        Expand-MtPackArchive -Archive $Archive -Destination $Destination
        Get-Content -LiteralPath (Join-Path $Destination 'nested/a.txt') -Raw | Should -Be 'content'
        (Get-MtPackDigest -Path $Destination).Files.Count | Should -Be 1
    }
}

Describe 'Pack security: publisher policy' {
    BeforeEach {
        $script:SavedPolicy = $env:MAESTER_PACK_POLICY
        $env:MAESTER_PACK_POLICY = $null
        Mock Test-Path { $false }
    }
    AfterEach { $env:MAESTER_PACK_POLICY = $SavedPolicy }

    It 'keeps <PolicyJson> unrestricted' -ForEach @(
        @{ PolicyJson = '{}' }
        @{ PolicyJson = '{"AllowedPublishers":null}' }
    ) {
        $Policy = Get-MtPackPolicy -RunConfig ([pscustomobject]@{ PackPolicy = ($PolicyJson | ConvertFrom-Json) })
        ($null -eq $Policy.AllowedPublishers) | Should -BeTrue
        Test-MtPackPolicy -Policy $Policy -PackId contoso.sample -Publisher contoso | Should -BeNullOrEmpty
    }

    It 'denies all publishers for <Case>' -ForEach @(
        @{ Case = 'an explicit empty list'; Config = @(); Environment = $null }
        @{ Case = 'disjoint restrictions'; Config = @('attacker'); Environment = '{"AllowedPublishers":["trusted-owner"]}' }
        @{ Case = 'empty config followed by a nonempty layer'; Config = @(); Environment = '{"AllowedPublishers":["attacker"]}' }
        @{ Case = 'empty environment after a nonempty layer'; Config = @('attacker'); Environment = '{"AllowedPublishers":[]}' }
    ) {
        $env:MAESTER_PACK_POLICY = $Environment
        $Policy = Get-MtPackPolicy -RunConfig ([pscustomobject]@{ PackPolicy = [pscustomobject]@{ AllowedPublishers = $Config } })
        ($null -eq $Policy.AllowedPublishers) | Should -BeFalse
        $Policy.AllowedPublishers.Count | Should -Be 0
        Test-MtPackPolicy -Policy $Policy -PackId attacker.pack -Publisher attacker | Should -Match 'does not allow'
        Test-MtPackPolicy -Policy $Policy -PackId attacker.pack | Should -Match 'does not allow'
        Test-MtPackPolicy -Policy $Policy -PackId maester.pack -BuiltIn | Should -BeNullOrEmpty
    }

    It 'preserves a case-insensitive intersection and rejects a missing publisher' {
        $env:MAESTER_PACK_POLICY = '{"AllowedPublishers":["CONTOSO","fabrikam"]}'
        $Policy = Get-MtPackPolicy -RunConfig ([pscustomobject]@{ PackPolicy = [pscustomobject]@{ AllowedPublishers = @('contoso', 'other') } })
        @($Policy.AllowedPublishers).Count | Should -Be 1
        Test-MtPackPolicy -Policy $Policy -PackId contoso.sample -Publisher Contoso | Should -BeNullOrEmpty
        Test-MtPackPolicy -Policy $Policy -PackId fabrikam.sample -Publisher fabrikam | Should -Match 'does not allow'
        Test-MtPackPolicy -Policy $Policy -PackId contoso.sample | Should -Match 'does not allow'
    }
}

Describe 'Pack security: blocklist freshness' {
    BeforeAll {
        $Key = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve+NamedCurves]::nistP256)
        $script:PublicKey = [System.Convert]::ToBase64String($Key.ExportSubjectPublicKeyInfo())
        function New-SecuritySignedList {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Returns an in-memory signed test envelope without changing external state.')]
            [CmdletBinding()]
            param([datetime] $Expires = [datetime]::UtcNow.AddDays(1))
            $Payload = [System.Text.Encoding]::UTF8.GetBytes((@{ Serial = 1; Expires = $Expires.ToString('o'); Entries = @() } | ConvertTo-Json))
            [pscustomobject]@{
                KeyId = 'test'
                Payload = [System.Convert]::ToBase64String($Payload)
                Signature = [System.Convert]::ToBase64String($Key.SignData($Payload, [System.Security.Cryptography.HashAlgorithmName]::SHA256))
            }
        }
    }
    AfterAll { $Key.Dispose() }
    BeforeEach {
        $script:__MtPackBlocklist = $null
        $CacheFile = Join-Path $TestDrive "$([guid]::NewGuid()).json"
        Mock Get-MtPackHome { [pscustomobject]@{ Blocklist = $CacheFile } }
        Mock Get-MtPackTrust { [pscustomobject]@{ Blocklist = [pscustomobject]@{ Url = 'https://packs.example/list'; Keys = @([pscustomobject]@{ KeyId = 'test'; PublicKey = $PublicKey }) } } }
        Mock Invoke-RestMethod { throw 'offline' }
    }
    AfterEach { $script:__MtPackBlocklist = $null }

    It 'rejects missing trust keys even after a permissive call' {
        Mock Get-MtPackTrust { [pscustomobject]@{ Blocklist = [pscustomobject]@{ Keys = @() } } }
        { Get-MtPackBlocklist -RequireFresh } | Should -Throw '*RequireFreshBlocklist*'
        (Get-MtPackBlocklist).Available | Should -BeFalse
        { Get-MtPackBlocklist -RequireFresh } | Should -Throw '*RequireFreshBlocklist*'
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'rejects a cached unavailable result when strictness changes' {
        (Get-MtPackBlocklist).Available | Should -BeFalse
        { Get-MtPackBlocklist -RequireFresh } | Should -Throw '*RequireFreshBlocklist*'
    }

    It 'rejects a cached fallback warning when strictness changes' {
        @{ FetchedAt = [datetime]::UtcNow.AddHours(-2).ToString('o'); HighestSerial = 1; Envelope = (New-SecuritySignedList) } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $CacheFile
        $Result = Get-MtPackBlocklist
        $Result.Available | Should -BeTrue
        $Result.Warning | Should -Not -BeNullOrEmpty
        { Get-MtPackBlocklist -RequireFresh } | Should -Throw '*RequireFreshBlocklist*'
    }

    It 'accepts a fresh verified list from network, memory and disk' {
        $SignedResponse = New-SecuritySignedList
        Mock Invoke-RestMethod { $SignedResponse }
        (Get-MtPackBlocklist -RequireFresh).Available | Should -BeTrue
        (Get-MtPackBlocklist -RequireFresh).Available | Should -BeTrue
        $script:__MtPackBlocklist = $null
        (Get-MtPackBlocklist -RequireFresh).Available | Should -BeTrue
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'rejects an empty refresh response instead of silently treating an old cache as fresh' {
        @{ FetchedAt = [datetime]::UtcNow.AddHours(-2).ToString('o'); HighestSerial = 1; Envelope = (New-SecuritySignedList) } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $CacheFile
        Mock Invoke-RestMethod { $null }
        { Get-MtPackBlocklist -RequireFresh } | Should -Throw '*RequireFreshBlocklist*'
        $Result = Get-MtPackBlocklist
        $Result.Available | Should -BeTrue
        $Result.Warning | Should -Match 'empty'
    }

    It 'does not extend signed expiry with the session cache' {
        $SignedResponse = New-SecuritySignedList
        Mock Invoke-RestMethod { $SignedResponse }
        $null = Get-MtPackBlocklist -RequireFresh
        $Expired = [datetime]::UtcNow.AddSeconds(-1)
        # Simulate time passing without sleeping; keep both signed disk data and session expiry consistent.
        $script:__MtPackBlocklist | Add-Member -NotePropertyName Expires -NotePropertyValue $Expired -Force
        @{ FetchedAt = [datetime]::UtcNow.ToString('o'); HighestSerial = 1; Envelope = (New-SecuritySignedList -Expires $Expired) } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $CacheFile
        Mock Invoke-RestMethod { throw 'offline' }
        { Get-MtPackBlocklist -RequireFresh } | Should -Throw '*RequireFreshBlocklist*'
    }
}

Describe 'Pack security: strongest blocklist match' {
    It 'prefers <Severity> to Warn for <Selector> in either order' -ForEach @(
        foreach ($Selector in @('Digest', 'RepositoryId', 'OwnerId', 'PackId')) {
            foreach ($Severity in @('Block', 'Unknown', '')) { @{ Selector = $Selector; Severity = $Severity } }
        }
    ) {
        $Warn = [pscustomobject]@{ OwnerId = 7; Severity = 'Warn'; Advisory = 'advisory' }
        $Values = @{ Digest = 'sha256:abc'; RepositoryId = 9; OwnerId = 7; PackId = 'contoso.sample' }
        $Block = [pscustomobject]@{ $Selector = $Values[$Selector]; Severity = $Severity; Advisory = 'stop' }
        foreach ($Entries in @(@($Warn, $Block), @($Block, $Warn))) {
            (Find-MtPackBlock -Entry $Entries -PackId contoso.sample -OwnerId 7 -RepositoryId 9 -Digest 'sha256:abc').Advisory | Should -Be 'stop'
        }
    }

    It 'returns an advisory when the only Block targets another version' {
        $Entries = @([pscustomobject]@{ OwnerId = 7; Severity = 'Warn' }, [pscustomobject]@{ PackId = 'contoso.sample'; Versions = '2.0.0'; Severity = 'Block' })
        (Find-MtPackBlock -Entry $Entries -OwnerId 7 -PackId contoso.sample -Version 1.0.0).Severity | Should -Be 'Warn'
        Find-MtPackBlock -Entry $Entries -OwnerId 8 -PackId other.pack | Should -BeNullOrEmpty
    }
}

Describe 'Pack security: GitHub commit provenance' {
    BeforeEach {
        $script:Source = [pscustomobject]@{ Owner = 'contoso'; Repo = 'pack'; Folder = $null; Ref = $null }
        $Commit = 'abcdef' + ('0' * 34)
        Mock Get-MtPackFirstSeen { [datetime]::UtcNow.AddDays(-4) }
        Mock Invoke-MtPackGitHubRequest {
            switch -Wildcard ($Path) {
                'repos/contoso/pack' { [pscustomobject]@{ id = 7; full_name = 'contoso/pack'; default_branch = 'main'; owner = [pscustomobject]@{ id = 9; login = 'contoso' } } }
                'repos/contoso/pack/commits/*' { [pscustomobject]@{ sha = $Commit } }
                'repos/contoso/pack/compare/*' { [pscustomobject]@{ status = 'ahead' } }
                default { $null }
            }
        }
    }

    It 'rejects an unreachable <Ref> even with IncludeRecent' -ForEach @(
        @{ Ref = 'a' }
        @{ Ref = 'abcdef' }
        @{ Ref = 'ABCDEF' }
        @{ Ref = 'abcdef0' }
        @{ Ref = ('a' * 40) }
    ) {
        $Source.Ref = $Ref
        { Resolve-MtPackGitHubSource -Source $Source -IncludeRecent } | Should -Throw '*not on the default branch*'
        Should -Invoke Invoke-MtPackGitHubRequest -ParameterFilter { $Path -like '*/compare/*' } -Times 1 -Exactly
    }

    It 'accepts a reachable abbreviated commit when compare reports <Status>' -ForEach @(
        @{ Status = 'behind' }
        @{ Status = 'identical' }
    ) {
        Mock Invoke-MtPackGitHubRequest { [pscustomobject]@{ status = $Status } } -ParameterFilter { $Path -like '*/compare/*' }
        $Source.Ref = 'abcdef'
        (Resolve-MtPackGitHubSource -Source $Source).Commit | Should -Be $Commit
    }

    It 'does not accept an arbitrary commits API expression as a named ref' {
        $Source.Ref = 'abcdef~1'
        { Resolve-MtPackGitHubSource -Source $Source } | Should -Throw '*not a branch or tag*'
        Should -Invoke Invoke-MtPackGitHubRequest -ParameterFilter { $Path -like '*/commits/*' } -Times 0
    }

    It 'retains a real repository <Kind> outside default-branch history' -ForEach @(
        @{ Kind = 'feature branch'; Ref = 'feature/security'; GitRef = 'refs/heads/feature/security' }
        @{ Kind = 'unreleased tag'; Ref = 'v0.9'; GitRef = 'refs/tags/v0.9' }
        @{ Kind = 'fully qualified branch'; Ref = 'refs/heads/feature/security'; GitRef = 'refs/heads/feature/security' }
        @{ Kind = 'hexadecimal branch'; Ref = 'decade'; GitRef = 'refs/heads/decade' }
        @{ Kind = 'numeric tag'; Ref = '1'; GitRef = 'refs/tags/1' }
    ) {
        Mock Invoke-MtPackGitHubRequest { [pscustomobject]@{ ref = $GitRef } } -ParameterFilter { $Path -like '*/git/ref/*' }
        $Source.Ref = $Ref
        (Resolve-MtPackGitHubSource -Source $Source).Commit | Should -Be $Commit
        Should -Invoke Invoke-MtPackGitHubRequest -ParameterFilter { $Path -like '*/compare/*' } -Times 0
    }
}
