Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-02" {
    It "AD-CFG-02: dSHeuristics count should be retrievable" {
        $result = Test-MtAdDsHeuristicsCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "dSHeuristics configuration should be accessible"
        }
    }
}
