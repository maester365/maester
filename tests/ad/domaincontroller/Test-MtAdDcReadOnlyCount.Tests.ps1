Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DCD-03" {
    It "AD-DCD-03: Read-only domain controller count should be retrievable" {

        $result = Test-MtAdDcReadOnlyCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "read-only domain controller data should be accessible"
        }
    }
}
