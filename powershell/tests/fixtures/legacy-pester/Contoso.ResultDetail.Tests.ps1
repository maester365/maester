# Legacy Pester fixture: custom tests that write report details with Add-MtTestResultDetail.
# Requires the Maester module to be imported; no tenant connection is needed.
Describe "Contoso result details" -Tag "Contoso" {
    It "CONTOSO.7001: Writes a description and a result" -Tag "CONTOSO.7001" {
        $users = @('alice', 'bob')
        $result = "Found $($users.Count) users."
        Add-MtTestResultDetail -Description "Checks that users exist." -Result $result -Severity 'Low'
        $users.Count | Should -BeGreaterThan 0
    }

    It "CONTOSO.7002: Skips with a custom reason" -Tag "CONTOSO.7002" {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Contoso API is not configured."
        $true | Should -BeTrue
    }

    It "CONTOSO.7003: Marks the result for investigation" -Tag "CONTOSO.7003" {
        Add-MtTestResultDetail -Description "Needs review." -Result "Two policies overlap." -Investigate
        $true | Should -BeTrue
    }
}
