Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-ROOTDSE-03" {
    It "AD-ROOTDSE-03: Root DSE synchronized status should be retrievable" {

        $result = Test-MtAdRootDseSynchronizedStatus

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Root DSE data should be accessible and DC should be synchronized"
        }
    }
}
