Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-ROOTDSE-03" {
    It "AD-ROOTDSE-03: Root DSE should be synchronized" {

        $result = Test-MtAdRootDseSynchronizedStatus

        if ($null -ne $result) {
            $result | Should -Be $true -Because "unsynchronized DCs can fail to receive security policy changes promptly"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
