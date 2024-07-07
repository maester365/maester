Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.8.1", "CISA", "Security", "All" {
    It "MS.EXO.8.1: A DLP solution SHALL be used." {

        $cisaDlp = Test-MtCisaDlp

        if ($null -ne $cisaDlp) {
            $cisaDlp | Should -Be $true -Because "DLP is enabled."
        }
    }
}