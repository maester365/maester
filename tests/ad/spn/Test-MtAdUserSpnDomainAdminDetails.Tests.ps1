Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-13" {
    It "AD-SPN-13: No domain admin accounts should have SPNs configured" {

        $result = Test-MtAdUserSpnDomainAdminDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain admin accounts with SPNs are vulnerable to Kerberoasting attacks"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
