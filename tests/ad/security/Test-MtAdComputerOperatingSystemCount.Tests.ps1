Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-04" {
    It "AD-DCOMP-04: Computer operating system count should be retrievable" {

        $result = Test-MtAdComputerOperatingSystemCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer operating system information should be accessible"
        }
    }
}
