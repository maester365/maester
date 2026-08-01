Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DC-06" {
    It "AD-DC-06: FSMO role holder details should be retrievable" {

        $result = Test-MtAdDcFsmoRoleHolderDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "FSMO role holder data should be accessible"
        }
    }
}
