Describe "CISA" -Tag "MS.EXO", "MS.EXO.11.1", "CISA.MS.EXO.11.1", "CISA", "Security" {
    It "CISA.MS.EXO.11.1: Impersonation protection checks SHOULD be used." {

        $result = Test-MtCisaImpersonation

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}
