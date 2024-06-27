Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.2.2", "CISA", "Security", "All" {
    It "MS.EXO.2.2: An SPF policy SHALL be published for each domain, designating only these addresses as approved senders." {
        $cisaSpfDirectives = Test-MtCisaSpfDirectives

        if ($null -ne $cisaSpfDirectives) {
            $cisaSpfDirectives | Should -Be $true -Because "SPF record should restrict authorized senders."
        }
    }
}