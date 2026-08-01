Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DC-08" {
    It "AD-DC-08: DC operating system details should be retrievable" {

        $result = Test-MtAdDcOperatingSystemDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DC operating system distribution data should be accessible"
        }
    }
}
