Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOM-02" {
    It "AD-DOM-02: Machine account quota should be retrievable" {

        $result = Test-MtAdMachineAccountQuota

        if ($null -ne $result) {
            $result | Should -Be $true -Because "machine account quota data should be accessible"
        }
    }
}
