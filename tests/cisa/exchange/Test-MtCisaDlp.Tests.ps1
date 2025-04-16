Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.8.1", "CISA.MS.EXO.08.1", "CISA", "Security", "All" {
    It "CISA.MS.EXO.08.1: A DLP solution SHALL be used." {

        $cisaDlp = Test-MtCisaDlp

        if ($null -ne $cisaDlp) {
            $cisaDlp | Should -Be $true -Because "DLP is enabled."
        }
    }
}