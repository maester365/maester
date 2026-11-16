BeforeAll {
    $script:Readable = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../../../tests/ad/replication/Test.AD-REPL-NC-01.ps1') -Raw
    $script:Core = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../../../tests/ad/replication/Test.AD-REPL-NC-02.ps1') -Raw
}
Describe 'Replication partition evidence disposition contract' {
    It 'distinguishes no connection from unavailable category evidence' {
        foreach ($source in $script:Readable,$script:Core) {
            $source | Should -Match 'SkippedBecause NotConnectedActiveDirectory'
            $source | Should -Match "SkippedBecause Custom -SkippedCustomReason 'Replication partition evidence is unavailable.'"
        }
    }
    It 'skips zero advertised naming-context evidence' {
        $script:Readable | Should -Match 'AdvertisedCount -eq 0'
        $script:Readable | Should -Match 'readability cannot be evaluated'
    }
}
