BeforeAll { $script:Source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../../../tests/ad/security/Test.AD-MSA-03.ps1') -Raw }
Describe 'AD-MSA-03 clean evidence disposition contract' {
    It 'returns success without Investigate when all evidence is complete' {
        $branch=[regex]::Match($script:Source,'if \(\$incomplete.Count -eq 0\).*?\n\s*}','Singleline').Value
        $branch | Should -Match 'return \$true'
        $branch | Should -Not -Match '-Investigate'
    }
}
