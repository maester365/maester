Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.17.3", "CISA", "Security", "All" {
    It "MS.EXO.17.3: Audit logs SHALL be maintained for at least the minimum duration dictated by OMB M-21-31 (Appendix C)." {

        $result = Test-MtCisaAuditLogRetention

        if ($null -ne $result) {
            $result | Should -Be $true -Because "enabled."
        }
    }
}