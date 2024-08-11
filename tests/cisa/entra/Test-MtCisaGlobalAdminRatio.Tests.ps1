Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.2", "CISA", "Security", "All", "Entra ID Free" {
    It "MS.AAD.7.2: Privileged users SHALL be provisioned with finer-grained roles instead of Global Administrator." {
        $result = Test-MtCisaGlobalAdminRatio

        if ($null -ne $result) {
            $result | Should -Be $true -Because "more granular role assignments exist than global admin assignments."
        }
    }
}