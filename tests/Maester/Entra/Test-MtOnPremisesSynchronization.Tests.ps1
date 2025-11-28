Describe 'Maester/Entra' -Tag 'DirSync', 'Entra', 'Graph', 'Maester', 'Security' {
    It 'MT.1073: Soft- and hard-matching of synchronized objects should be blocked. See https://maester.dev/docs/tests/MT.1073' -Tag 'MT.1073' {
        Test-MtEntraIDConnectSyncSoftHardMatching | Should -Be $true -Because 'on-premises directory synchronization soft- and hard-match is blocked'
    }
}
