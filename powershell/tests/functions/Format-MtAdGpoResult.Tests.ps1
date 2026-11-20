BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Format-MtAdGpoResult' {
    It 'escapes tenant-controlled metric labels, values, headers and detail cells without changing trusted summary Markdown' {
        InModuleScope Maester {
            $tenantText = "<&|[x](https://evil.example) ![x](https://evil.example/p.png) https://evil.example www.evil.example a@b.example`r`nnext\end"
            $escaped = '&lt;&amp;&#124;\[x\]\(https\://evil.example\) \!\[x\]\(https\://evil.example/p.png\) https\://evil.example www\.evil.example a\@b.example next\\end'
            $summary = '**Trusted summary** [help](https://maester.dev)'
            $metrics = [ordered]@{}
            $metrics[$tenantText] = $tenantText
            $result = Format-MtAdGpoResult -Summary $summary -Metrics $metrics `
                -Details @([pscustomobject]@{ Name = $tenantText }) -Properties @('Name') -Headers @($tenantText)

            $expected = @(
                $summary
                ''
                '| Metric | Value |'
                '| --- | --- |'
                "| $escaped | $escaped |"
                ''
                ''
                '#### Details'
                ''
                "| $escaped |"
                '| --- |'
                "| $escaped |"
                ''
            ) -join "`n"
            $result | Should -BeExactly $expected
            $result | Should -Not -Match '\\&#124;'
        }
    }

    It 'preserves every row in a large detail table and renders one header' {
        InModuleScope Maester {
            $rows = @(0..2999 | ForEach-Object { [pscustomobject]@{ Name = "policy-$_"; Enabled = $false } })
            $result = Format-MtAdGpoResult -Summary 'Inventory' -Details $rows -Properties @('Name', 'Enabled')
            $result | Should -Match '^Inventory\n\n#### Details\n\n\| Name \| Enabled \|\n\| --- \| --- \|\n'
            @($result -split "`n" | Where-Object { $_ -match '^\| policy-\d+ \| False \|$' }) | Should -HaveCount 3000
            $result | Should -Match '(?m)^\| policy-0 \| False \|$'
            $result | Should -Match '(?m)^\| policy-2999 \| False \|$'
            @($result -split "`n" | Where-Object { $_ -eq '| Name | Enabled |' }) | Should -HaveCount 1
        }
    }

    It 'keeps False distinct from null and omits empty detail tables' {
        InModuleScope Maester {
            $result = Format-MtAdGpoResult -Summary 'Summary' -Metrics ([ordered]@{ Enabled = $false; Missing = $null }) `
                -Details @($null) -Properties @('Name')
            $result | Should -BeExactly "Summary`n`n| Metric | Value |`n| --- | --- |`n| Enabled | False |`n| Missing | Unknown |`n"
            $result | Should -Not -Match '#### Details'
            Format-MtAdGpoResult -Summary 'Summary' -Details @() | Should -BeExactly 'Summary'

            $detail = Format-MtAdGpoResult -Summary 'Summary' -Details @([pscustomobject]@{ Enabled = $false; Missing = $null }) `
                -Properties @('Enabled', 'Missing')
            $detail | Should -Match '(?m)^\| False \| Unknown \|$'
        }
    }

    It 'requires matching headers and properties for non-empty detail rows' {
        InModuleScope Maester {
            $details = @([pscustomobject]@{ Name = 'Policy' })
            { Format-MtAdGpoResult -Summary 'Summary' -Details $details } | Should -Throw '*Detail properties are required*'
            { Format-MtAdGpoResult -Summary 'Summary' -Details $details -Properties @('Name') -Headers @('One', 'Two') } |
                Should -Throw '*headers and properties must have the same count*'
        }
    }
}
