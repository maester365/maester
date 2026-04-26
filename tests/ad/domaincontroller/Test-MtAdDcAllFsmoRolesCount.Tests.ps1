Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DC-05" {
    It "AD-DC-05: DCs with all FSMO roles count should be retrievable" {

        $result = Test-MtAdDcAllFsmoRolesCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "FSMO role data should be accessible"
        }
    }
}
