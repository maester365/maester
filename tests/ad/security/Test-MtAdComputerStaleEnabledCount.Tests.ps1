Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-06" {
    It "AD-DCOMP-06: Stale enabled computer count should be retrievable" {

        $result = Test-MtAdComputerStaleEnabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "stale enabled computer information should be accessible"
        }
    }
}
