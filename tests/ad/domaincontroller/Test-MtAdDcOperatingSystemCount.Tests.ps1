Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DC-07" {
    It "AD-DC-07: DC operating system count should be retrievable" {

        $result = Test-MtAdDcOperatingSystemCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DC operating system data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
