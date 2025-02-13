Describe "Roles and permissions" -Tag "Full", "Entra", "Graph", "App" {
    It "MT.1050 Apps with high-risk permissions having a direct or indirect path to Global Admin" -Tag "MT.1050" {
        $result = Test-MtHighRiskAppPermissions
        if ($null -ne $result) {
            $result | Should -Be $true -Because "no graph application has permissions with a risk of having a direct or indirect path to Global Admin and full tenant takeover."
        }
    }
}