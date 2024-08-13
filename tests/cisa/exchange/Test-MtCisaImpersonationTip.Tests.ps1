Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.11.2", "CISA", "Security", "All" {
    It "MS.EXO.11.2: User warnings, comparable to the user safety tips included with EOP, SHOULD be displayed." {

        $result = Test-MtCisaImpersonationTip

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}