Describe 'Maester/Entra' -Tag 'DirSync', 'Entra', 'Graph', 'Maester', 'Security' {
    It 'MT.1073: Soft- and hard-matching of synchronized objects should be blocked. See https://maester.dev/docs/tests/MT.1073' -Tag 'MT.1073' {
        Test-MtDirSyncSoftHardMatching | Should -Be $true -Because 'on-premises directory synchronization soft- and hard-match is blocked'
    }
    It 'MT.1099: Latest version of Entra Connect Sync Server should be installed. See https://maester.dev/docs/tests/MT.1099' -Tag 'MT.1099' {
        Test-MtEntraConnectSyncVersion | Should -Be $true -Because 'latest version of Entra Connect Sync Server is not installed'
    }
}
