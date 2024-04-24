Describe "CISA ScubaGear MS.AAD.2.2v1" -Tag "CISA", "Security", "All" {
    It "MS.AAD.2.2v1: A notification SHOULD be sent to the administrator when high-risk users are detected." {
        Test-MtCisaNotifyHighRisk | Should -Be $true -Because "an enabled is a recipient of risky user login notifications."
    }
}