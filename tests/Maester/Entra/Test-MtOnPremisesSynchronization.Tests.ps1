Describe 'Maester/Entra' -Tag 'Entra', 'Graph', 'Hybrid', 'Maester' {
    It 'MT.1073: Soft- and hard-matching of synchronized objects should be blocked. See https://maester.dev/docs/tests/MT.1073' -Tag 'MT.1073' {
        Test-MtEntraIDConnectSyncSoftHardMatching | Should -Be $true -Because 'on-premises directory synchronization soft- and hard-match is blocked'
    }

    It 'MT.1147: Do not sync krbtgt_AzureAD to Entra ID. See https://maester.dev/docs/tests/MT.1147' -Tag 'MT.1147' {
        Test-MtKrbtgtAzureADNotSynced | Should -Be $true -Because 'krbtgt_AzureAD should exist only in Entra ID and should not be synchronized from on-premises Active Directory'
    }
}
