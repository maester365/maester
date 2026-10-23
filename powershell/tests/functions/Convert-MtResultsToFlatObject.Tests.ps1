BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    function New-TestRow ([string]$Id, [string]$Detail) {
        [pscustomobject]@{
            ID = $Id; Title = "Title $Id"; Result = 'Passed'; Severity = 'High'; Tag = @('t'); Block = 'b'; Duration = '00:00:01'
            Name = "Name $Id"; HelpUrl = ''; ScriptBlockFile = "/tests/Test.$Id.ps1"
            ResultDetail = [pscustomobject]@{ TestResult = $Detail; TestDescription = ''; TestSkipped = ''; SkippedReason = '' }
            ErrorRecord = $null
        }
    }
}

Describe 'Convert-MtResultsToFlatObject' -Tag 'Unit' {
    It 'keeps the detail of each test under its own ID' {
        $result = [pscustomobject]@{ Tests = @((New-TestRow 'A' 'detail A'), (New-TestRow 'B' 'detail B')) }

        $flat = Convert-MtResultsToFlatObject -InputObject $result -WarningAction SilentlyContinue

        ($flat | Where-Object ID -eq 'A').ResultDetail | Should -Be 'detail A'
        ($flat | Where-Object ID -eq 'B').ResultDetail | Should -Be 'detail B'
    }

    It 'truncates the detail of a long test from its own text, not from the previous row' {
        $long = "START-OF-LONG`n`n#### Impacted resources`n$('x' * 40000)`n#### Remediation actions:`nfix it"
        $result = [pscustomobject]@{ Tests = @((New-TestRow 'A' 'detail A'), (New-TestRow 'B' $long)) }

        $flat = Convert-MtResultsToFlatObject -InputObject $result -WarningAction SilentlyContinue
        $row = $flat | Where-Object ID -eq 'B'

        $row.ResultDetail | Should -BeLike '*START-OF-LONG*'
        $row.ResultDetail | Should -Not -BeLike '*detail A*'
        $row.ResultDetail | Should -BeLike '*fix it*'
    }

    It 'does not put another test''s text under a long test that comes first' {
        $long = "START-OF-LONG`n`n#### Impacted resources`n$('x' * 40000)`n#### Remediation actions:`nfix it"
        $result = [pscustomobject]@{ Tests = @((New-TestRow 'A' $long)) }

        $flat = Convert-MtResultsToFlatObject -InputObject $result -WarningAction SilentlyContinue

        $flat[0].ResultDetail | Should -BeLike '*START-OF-LONG*'
    }

    It 'keeps a long detail without the section headings within 30000 characters' {
        $long = "START-OF-LONG`n$('x' * 40000)"
        $result = [pscustomobject]@{ Tests = @((New-TestRow 'A' $long)) }

        $flat = Convert-MtResultsToFlatObject -InputObject $result -WarningAction SilentlyContinue

        $flat[0].ResultDetail.Length | Should -BeLessOrEqual 30000
        $flat[0].ResultDetail | Should -BeLike 'NOTE: DETAILS ARE TRUNCATED*START-OF-LONG*'
    }

    It 'leaves a detail of exactly 30000 characters unchanged' {
        $detail = 'y' * 30000
        $result = [pscustomobject]@{ Tests = @((New-TestRow 'A' $detail)) }

        $flat = Convert-MtResultsToFlatObject -InputObject $result -WarningAction SilentlyContinue

        $flat[0].ResultDetail | Should -BeExactly $detail
    }
}
