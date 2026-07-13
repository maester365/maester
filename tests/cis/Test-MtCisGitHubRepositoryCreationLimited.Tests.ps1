Describe "CIS" -Tag "CIS.GH.1.2.2", "L1", "CIS GH Level 1", "CIS GH", "GitHub", "CIS", "CIS GitHub v1.2.0" {
    It "CIS.GH.1.2.2: Ensure repository creation is limited to specific members" {
        $result = Test-MtCisGitHubRepositoryCreationLimited

        if ($null -ne $result) {
            $result | Should -Be $true -Because "members cannot create public or private repositories"
        }
    }
}
