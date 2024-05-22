Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.3", "CISA", "Security", "All" {
    It "MS.AAD.7.3: Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers." {
        Test-MtCisaCloudGlobalAdmin | Should -Be $true -Because "no hybrid Global Administrators exist."
    }
}