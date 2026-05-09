Describe "CIS" -Tag "CIS.GH.1.2.3", "L1", "CIS GH Level 1", "CIS GH", "CIS", "CIS GitHub v1.2.0" {
    It "CIS.GH.1.2.3: Ensure repository deletion is limited to specific users" {
        $result = Test-MtCisGitHubRepositoryDeletionLimited

        if ($null -ne $result) {
            $result | Should -Be $true -Because "members_can_delete_repositories is false"
        }
    }
}
