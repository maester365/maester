BeforeAll {
    foreach ($SourceFile in @('Get-MtPackDigest', 'Invoke-MtPackInstall', 'Save-MtPackModule', 'Get-MtPackHome', 'Read-MtPackLock', 'Resolve-MtPackLockPath', 'Get-MtPackCandidate', 'ConvertFrom-MtPackSource', 'Get-MtBuiltInPack')) {
        . "$PSScriptRoot/../../internal/packs/$SourceFile.ps1"
    }
    . "$PSScriptRoot/../../public/packs/Restore-MtPack.ps1"
}

Describe 'Pack security: approved store recovery' {
    BeforeEach {
        $Root = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        $CandidateRoot = Join-Path $Root 'candidate'
        $Store = Join-Path $Root 'store'
        $null = New-Item -Path "$CandidateRoot/nested", $Store -ItemType Directory -Force
        [System.IO.File]::WriteAllText("$CandidateRoot/nested/helper.ps1", "'approved'")
        $Digest = (Get-MtPackDigest -Path $CandidateRoot).Digest
        Mock Get-MtPackHome { [pscustomobject]@{ Store = $Store; Modules = "$Root/modules" } }
        $script:Target = Save-MtPackToStore -Path $CandidateRoot -Digest $Digest
        $LockPath = Join-Path $Root 'maester-packs.lock.json'
        @{ Packs = @(@{ Id = 'contoso.sample'; Version = '1.0.0'; Source = 'github.com/contoso/pack'; Commit = ('a' * 40); Digest = $Digest }); Modules = @() } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $LockPath
        Mock Resolve-MtPackLockPath { [pscustomobject]@{ LockPath = $LockPath } }
        Mock Get-MtPackCandidate { [pscustomobject]@{ Root = $CandidateRoot; Digest = $Digest; Staging = $null } }
    }

    It '<Operation> replaces a stored pack with a stream on <Location>' -Skip:(-not $IsWindows) -ForEach @(
        foreach ($Operation in @('Restore', 'Reinstall')) {
            foreach ($Location in @('file', 'directory', 'root')) { @{ Operation = $Operation; Location = $Location } }
        }
    ) {
        $Contaminated = switch ($Location) { 'file' { "$Target/nested/helper.ps1" }; 'directory' { "$Target/nested" }; 'root' { $Target } }
        if ($Location -eq 'file') { (Get-Item -LiteralPath $Contaminated).IsReadOnly = $false }
        Set-Content -LiteralPath $Contaminated -Stream Zone.Identifier -Value 'unapproved'
        if ($Operation -eq 'Restore') {
            $Result = Restore-MtPack -PackLock $LockPath -Confirm:$false
            $Result.Status | Should -Be 'Restored'
            $Result.Reason | Should -BeNullOrEmpty
            Should -Invoke Get-MtPackCandidate -Times 1 -Exactly
        } else {
            Save-MtPackToStore -Path $CandidateRoot -Digest $Digest | Should -Be $Target
        }
        (Get-MtPackDigest -Path $Target).Digest | Should -Be $Digest
        Get-Content -LiteralPath "$Target/nested/helper.ps1" -Raw | Should -Be "'approved'"
    }

    It '<Operation> preserves the existing store when the candidate has <Problem>' -Skip:(-not $IsWindows) -ForEach @(
        foreach ($Operation in @('Restore', 'Reinstall')) {
            foreach ($Problem in @('wrong digest', 'file stream', 'directory stream', 'root stream')) { @{ Operation = $Operation; Problem = $Problem } }
        }
    ) {
        Set-Content -LiteralPath $Target -Stream payload -Value 'retain until verified'
        switch ($Problem) {
            'wrong digest' { [System.IO.File]::WriteAllText("$CandidateRoot/nested/helper.ps1", "'unapproved'") }
            'file stream' { Set-Content -LiteralPath "$CandidateRoot/nested/helper.ps1" -Stream payload -Value 'unapproved' }
            'directory stream' { Set-Content -LiteralPath "$CandidateRoot/nested" -Stream payload -Value 'unapproved' }
            'root stream' { Set-Content -LiteralPath $CandidateRoot -Stream payload -Value 'unapproved' }
        }
        if ($Operation -eq 'Restore') {
            $Result = Restore-MtPack -PackLock $LockPath -Confirm:$false -ErrorAction SilentlyContinue
            $Result.Status | Should -Be 'Failed'
            $Result.Reason | Should -Match 'approved digest|alternate data stream'
            Should -Invoke Get-MtPackCandidate -Times 1 -Exactly
        } else {
            { Save-MtPackToStore -Path $CandidateRoot -Digest $Digest } | Should -Throw
        }
        Get-Content -LiteralPath $Target -Stream payload | Should -Be 'retain until verified'
        Get-Content -LiteralPath "$Target/nested/helper.ps1" -Raw | Should -Be "'approved'"
        @(Get-ChildItem -LiteralPath $Store -Filter '*.tmp').Count | Should -Be 0
    }

    It 'reports a failed download per pack and preserves the contaminated store' -Skip:(-not $IsWindows) {
        Set-Content -LiteralPath $Target -Stream payload -Value 'retain'
        Mock Get-MtPackCandidate { throw 'download unavailable' }
        $Result = Restore-MtPack -PackLock $LockPath -Confirm:$false -ErrorAction SilentlyContinue
        $Result.Status | Should -Be 'Failed'
        $Result.Reason | Should -Be 'download unavailable'
        Get-Content -LiteralPath $Target -Stream payload | Should -Be 'retain'
    }

    It 'keeps an ordinary valid stored pack unchanged without a download or copy' {
        Mock Copy-Item { throw 'Valid stored content must not be copied again.' }
        $Before = (Get-Item -LiteralPath "$Target/nested/helper.ps1").LastWriteTimeUtc
        (Restore-MtPack -PackLock $LockPath -Confirm:$false).Status | Should -Be 'Present'
        Save-MtPackToStore -Path $CandidateRoot -Digest $Digest | Should -Be $Target
        (Get-Item -LiteralPath "$Target/nested/helper.ps1").LastWriteTimeUtc | Should -Be $Before
        (Get-MtPackDigest -Path $Target).Digest | Should -Be $Digest
        Should -Invoke Get-MtPackCandidate -Times 0 -Exactly
        Should -Invoke Copy-Item -Times 0 -Exactly
    }

    It 'preserves the old store and cleans staging if copying produces <Problem>' -Skip:(-not $IsWindows) -ForEach @(
        @{ Problem = 'different bytes' }
        @{ Problem = 'a prohibited stream' }
        @{ Problem = 'an I/O error' }
    ) {
        Set-Content -LiteralPath $Target -Stream payload -Value 'retain'
        Mock Copy-Item {
            $null = New-Item -Path "$Destination/nested" -ItemType Directory -Force
            if ($Problem -eq 'an I/O error') { throw [System.IO.IOException]::new('copy failed') }
            $Content = if ($Problem -eq 'different bytes') { "'changed during copy'" } else { "'approved'" }
            [System.IO.File]::WriteAllText("$Destination/nested/helper.ps1", $Content)
            if ($Problem -eq 'a prohibited stream') { Set-Content -LiteralPath $Destination -Stream payload -Value 'unapproved' }
        }
        { Save-MtPackToStore -Path $CandidateRoot -Digest $Digest } | Should -Throw
        Get-Content -LiteralPath $Target -Stream payload | Should -Be 'retain'
        Get-Content -LiteralPath "$Target/nested/helper.ps1" -Raw | Should -Be "'approved'"
        @(Get-ChildItem -LiteralPath $Store -Filter '*.tmp').Count | Should -Be 0
    }

    It 'does not treat an unrelated store read failure as replaceable content' {
        Mock Get-MtPackDigest { throw [System.IO.IOException]::new('read denied') } -ParameterFilter { $Path -eq $Target }
        { Save-MtPackToStore -Path $CandidateRoot -Digest $Digest } | Should -Throw '*read denied*'
        $Result = Restore-MtPack -PackLock $LockPath -Confirm:$false -ErrorAction SilentlyContinue
        $Result.Status | Should -Be 'Failed'
        $Result.Reason | Should -Be 'read denied'
        Should -Invoke Get-MtPackCandidate -Times 0 -Exactly
        Get-Content -LiteralPath "$Target/nested/helper.ps1" -Raw | Should -Be "'approved'"
    }
}

Describe 'Pack security: local candidate root' {
    BeforeEach { Mock Get-MtBuiltInPack { @() } }
    It 'rejects root streams before local candidate staging can drop them' -Skip:(-not $IsWindows) {
        $CandidateRoot = Join-Path $TestDrive 'local-pack'
        $null = New-Item -Path $CandidateRoot -ItemType Directory
        Set-Content -LiteralPath $CandidateRoot -Stream payload -Value 'unapproved'
        { Get-MtPackCandidate -Source $CandidateRoot } | Should -Throw '*alternate data stream*'
    }
}
