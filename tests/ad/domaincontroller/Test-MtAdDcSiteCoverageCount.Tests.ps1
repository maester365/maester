Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DC-01" {
    It "AD-DC-01: DC site coverage count should be retrievable" {

        $result = Test-MtAdDcSiteCoverageCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain controller site coverage data should be accessible"
        }
    }
}
