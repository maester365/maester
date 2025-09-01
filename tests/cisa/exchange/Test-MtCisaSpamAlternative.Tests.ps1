Describe "CISA" -Tag "MS.EXO", "MS.EXO.14.4", "CISA.MS.EXO.14.4", "CISA", "Security" {
    It "CISA.MS.EXO.14.4: If a third-party party filtering solution is used, the solution SHOULD offer services comparable to the native spam filtering offered by Microsoft." {

        $result = Test-MtCisaSpamAlternative

        if ($null -ne $result) {
            $result | Should -Be $true -Because "should not pass."
        }
    }
}
