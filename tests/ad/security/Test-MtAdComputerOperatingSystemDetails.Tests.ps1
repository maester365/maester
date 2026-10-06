Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-05" {
    It "AD-DCOMP-05: Computer operating system details should be investigated" {

        $result = Test-MtAdComputerOperatingSystemDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer operating system details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
