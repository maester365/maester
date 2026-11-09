BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'AD assessment summary tables' {
    It 'preserves field order, zero and false values, and escapes table cells' {
        InModuleScope Maester {
            $table = Format-MtAdSummaryTable -Values ([ordered]@{
                'First | metric' = 0
                'Enabled' = $false
                'Label' = "<script>|name`nnext"
            })
            $table | Should -Match '^\| Metric \| Value \|'
            $table | Should -Match '\| First &#124; metric \| 0 \|'
            $table | Should -Match '\| Enabled \| False \|'
            $table | Should -Match '&lt;script&gt;&#124;name next'
            $table.IndexOf('First') | Should -BeLessThan $table.IndexOf('Enabled')
        }
    }
}
