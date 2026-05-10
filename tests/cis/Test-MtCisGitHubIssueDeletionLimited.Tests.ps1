Describe "CIS" -Tag "CIS.GH.1.2.4", "L1", "CIS GH Level 1", "CIS GH", "CIS", "CIS GitHub v1.2.0" {
    It "CIS.GH.1.2.4: Ensure issue deletion is limited to specific users" {
        $result = Test-MtCisGitHubIssueDeletionLimited

        $result | Should -BeNullOrEmpty -Because "CIS GH 1.2.4 requires manual trust review after collecting issue deletion setting evidence"
    }
}
