Describe "CIS" -Tag "CIS.GH.1.3.2", "L1", "CIS GH Level 1", "CIS GH", "CIS", "CIS GitHub v1.2.0" {
    It "CIS.GH.1.3.2: Ensure team creation is limited to specific members" {
        $result = Test-MtCisGitHubTeamCreationLimited

        if ($null -ne $result) {
            $result | Should -Be $true -Because "members_can_create_teams is false"
        }
    }
}
