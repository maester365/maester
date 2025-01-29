Describe "Roles and permissions" -Tag "All", "Entra", "Graph" {
    It "Ensure no graph application has permissions with a risk of having a direct or indirect path to Global Admin and full tenant takeover." -Tag "MS.AAD.9.0" {
        $result = Test-MtHighRiskAppPermissions
        if ($null -ne $result) {
            $result | Should -Be $true -Because "no graph application has permissions with a risk of having a direct or indirect path to Global Admin and full tenant takeover."
        }
    }
}