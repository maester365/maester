Describe "CIS" -Tag "CIS.GH.1.2.3", "L1", "CIS GH Level 1", "CIS GH", "CIS", "CIS GitHub v1.2.0" {
    It "CIS.GH.1.2.3: Ensure repository deletion is limited to specific users" {
        $result = Test-MtCisGitHubRepositoryDeletionLimited

        $result | Should -BeNullOrEmpty -Because "CIS GH 1.2.3 requires manual trust review after collecting repository deletion setting evidence"
    }
}
