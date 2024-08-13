Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.11.1", "CISA", "Security", "All" {
    It "MS.EXO.11.1: Impersonation protection checks SHOULD be used." {

        $result = Test-MtCisaImpersonation

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}