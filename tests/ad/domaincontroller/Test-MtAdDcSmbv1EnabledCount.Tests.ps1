Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DC-02" {
    It "AD-DC-02: SMBv1 should be disabled on all domain controllers" {

        $result = Test-MtAdDcSmbv1EnabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "SMBv1 is a security risk and should be disabled on all DCs"
        }
    }
}
