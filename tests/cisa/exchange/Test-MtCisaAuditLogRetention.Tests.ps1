Describe "CISA" -Tag "MS.EXO", "MS.EXO.17.3", "CISA.MS.EXO.17.3", "CISA", "Security" {
    It "CISA.MS.EXO.17.3: Audit logs SHALL be maintained for at least the minimum duration dictated by OMB M-21-31 (Appendix C)." {

        $result = Test-MtCisaAuditLogRetention

        if ($null -ne $result) {
            $result | Should -Be $true -Because "enabled."
        }
    }
}
