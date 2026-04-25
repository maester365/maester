Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-03" {
    It "AD-CFG-03: SPN mappings should be retrievable" {
        $result = Test-MtAdSpnMappings
        if ($null -ne $result) {
            $result | Should -Be $true -Because "SPN mapping configuration should be accessible"
        }
    }
}
