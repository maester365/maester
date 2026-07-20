Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DC-03" {
    It "AD-DC-03: SMBv3.1.1 enabled count should be retrievable" {

        $result = Test-MtAdDcSmbv311EnabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "SMB configuration data should be accessible"
        }
    }
}
