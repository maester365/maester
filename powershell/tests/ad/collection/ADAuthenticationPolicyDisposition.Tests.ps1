BeforeAll { $script:Source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../../../tests/ad/config/Test.AD-CFG-08.ps1') -Raw }
Describe 'AD-CFG-08 evidence disposition contract' {
    It 'distinguishes no connection from missing category evidence' {
        $script:Source | Should -Match 'if \(\$null -eq \$adState\)'
        $script:Source | Should -Match 'SkippedBecause NotConnectedActiveDirectory'
        $script:Source | Should -Match "SkippedBecause Custom -SkippedCustomReason 'Authentication Policy LDAP evidence is unavailable.'"
    }
}
