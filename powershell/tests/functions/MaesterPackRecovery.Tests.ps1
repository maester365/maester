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

    It '<Operation> replaces a stored pack whose files were changed' -ForEach @(@{ Operation = 'Restore' }, @{ Operation = 'Reinstall' }) {
        $Changed = "$Target/nested/helper.ps1"
        if ($IsWindows) { (Get-Item -LiteralPath $Changed).IsReadOnly = $false }
        [System.IO.File]::WriteAllText($Changed, "'tampered'")
        if ($Operation -eq 'Restore') {
            $Result = Restore-MtPack -PackLock $LockPath -Confirm:$false
            $Result.Status | Should -Be 'Restored'
            $Result.Reason | Should -BeNullOrEmpty
            Should -Invoke Get-MtPackCandidate -Times 1 -Exactly
        } else {
            Save-MtPackToStore -Path $CandidateRoot -Digest $Digest -WarningAction SilentlyContinue | Should -Be $Target
        }
        (Get-MtPackDigest -Path $Target).Digest | Should -Be $Digest
        Get-Content -LiteralPath "$Target/nested/helper.ps1" -Raw | Should -Be "'approved'"
    }

    It '<Operation> keeps the existing store when the candidate is not the approved files' -ForEach @(@{ Operation = 'Restore' }, @{ Operation = 'Reinstall' }) {
        $Changed = "$Target/nested/helper.ps1"
        if ($IsWindows) { (Get-Item -LiteralPath $Changed).IsReadOnly = $false }
        [System.IO.File]::WriteAllText($Changed, "'kept until a verified copy replaces it'")
        [System.IO.File]::WriteAllText("$CandidateRoot/nested/helper.ps1", "'unapproved'")
        if ($Operation -eq 'Restore') {
            Mock Get-MtPackCandidate { [pscustomobject]@{ Root = $CandidateRoot; Digest = $Digest; Staging = $null } }
            $Result = Restore-MtPack -PackLock $LockPath -Confirm:$false -ErrorAction SilentlyContinue
            $Result.Status | Should -Be 'Failed'
            $Result.Reason | Should -Match 'approved digest'
        } else {
            { Save-MtPackToStore -Path $CandidateRoot -Digest $Digest } | Should -Throw '*approved digest*'
        }
        Get-Content -LiteralPath $Changed -Raw | Should -Be "'kept until a verified copy replaces it'"
        @(Get-ChildItem -LiteralPath $Store -Filter '*.tmp').Count | Should -Be 0
    }

    It 'reports a failed download per pack and keeps the changed store' {
        $Changed = "$Target/nested/helper.ps1"
        if ($IsWindows) { (Get-Item -LiteralPath $Changed).IsReadOnly = $false }
        [System.IO.File]::WriteAllText($Changed, "'kept'")
        Mock Get-MtPackCandidate { throw 'download unavailable' }
        $Result = Restore-MtPack -PackLock $LockPath -Confirm:$false -ErrorAction SilentlyContinue
        $Result.Status | Should -Be 'Failed'
        $Result.Reason | Should -Be 'download unavailable'
        Get-Content -LiteralPath $Changed -Raw | Should -Be "'kept'"
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

    It 'keeps the old store and cleans staging if copying produces <Problem>' -ForEach @(
        @{ Problem = 'different bytes' }
        @{ Problem = 'an I/O error' }
    ) {
        $Changed = "$Target/nested/helper.ps1"
        if ($IsWindows) { (Get-Item -LiteralPath $Changed).IsReadOnly = $false }
        [System.IO.File]::WriteAllText($Changed, "'kept'")
        Mock Copy-Item {
            $null = New-Item -Path "$Destination/nested" -ItemType Directory -Force
            if ($Problem -eq 'an I/O error') { throw [System.IO.IOException]::new('copy failed') }
            [System.IO.File]::WriteAllText("$Destination/nested/helper.ps1", "'changed during copy'")
        }
        { Save-MtPackToStore -Path $CandidateRoot -Digest $Digest } | Should -Throw
        Get-Content -LiteralPath $Changed -Raw | Should -Be "'kept'"
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
