Describe "Active Directory - Organizational Units" -Tag "AD", "AD.OU", "AD-OU-03" {
    It "AD-OU-03: OU stale count should be retrievable" {

        $result = Test-MtAdOuStaleCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "OU data should be accessible to identify stale OUs"
        }
    }
}
