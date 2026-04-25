Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-08" {
    It "AD-CFG-08: AuthN policy container count should be retrievable" {
        $result = Test-MtAdAuthNPolicyConfigCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "authentication policy configuration should be accessible"
        }
    }
}
