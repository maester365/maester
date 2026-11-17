BeforeAll { $script:Source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../../../tests/ad/dns/Test.AD-DNS-21.ps1') -Raw }
Describe 'AD-DNS-21 clean evidence disposition contract' {
    It 'returns success without Investigate when no unresolved trustee exists' {
        $branch=[regex]::Match($script:Source,'if \(\$items.Count -eq 0\).*?\n\s*}','Singleline').Value
        $branch | Should -Match 'return \$true'
        $branch | Should -Not -Match '-Investigate'
    }
}
