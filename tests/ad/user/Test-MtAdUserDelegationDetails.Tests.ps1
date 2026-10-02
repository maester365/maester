Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-29" {
    It "AD-USER-29: No users should be configured for unconstrained delegation" {
        $result = Test-MtAdUserDelegationDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "unconstrained delegation allows ticket reuse beyond intended services"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
