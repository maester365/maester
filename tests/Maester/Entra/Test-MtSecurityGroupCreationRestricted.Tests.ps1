Describe "Maester/Entra" -Tag "Governance", "Entra", "Security" {
    It "MT.1069: Restrict non-admin users from creating security groups." -Tag "MT.1069" {
        $result = Test-MtSecurityGroupCreationRestricted
        $result | Should -Be $true -Because "Non-admin users should be restricted from creating new security groups."
    }
}
