Describe "CIS" -Tag "CIS.GH.1.3.8", "L1", "CIS GH Level 1", "CIS GH", "CIS", "CIS GitHub v1.2.0" {
    It "CIS.GH.1.3.8: Ensure strict base permissions are set for repositories" {
        $result = Test-MtCisGitHubStrictBasePermission

        if ($null -ne $result) {
            $result | Should -Be $true -Because "default_repository_permission is none or read"
        }
    }
}
