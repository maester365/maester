Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.3", "CISA", "Security", "All", "Entra ID Free" {
    It "MS.AAD.7.3: Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers." {
        $result = Test-MtCisaCloudGlobalAdmin

        if ($null -ne $result) {
            $result | Should -Be $true -Because "no hybrid Global Administrators exist."
        }
    }
}