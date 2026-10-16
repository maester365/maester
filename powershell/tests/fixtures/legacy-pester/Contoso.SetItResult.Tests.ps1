# Legacy Pester fixture: Set-ItResult -Skipped and -Inconclusive inside the test body.
Describe "Contoso conditional results" -Tag "Contoso" {
    It "CONTOSO.5001: Skipped from inside the body" -Tag "CONTOSO.5001" {
        $licensed = $false
        if (-not $licensed) {
            Set-ItResult -Skipped -Because "the tenant has no Contoso licence"
            return
        }
        $true | Should -BeTrue
    }

    It "CONTOSO.5002: Inconclusive from inside the body" -Tag "CONTOSO.5002" {
        Set-ItResult -Inconclusive -Because "the data needs manual review"
    }
}
