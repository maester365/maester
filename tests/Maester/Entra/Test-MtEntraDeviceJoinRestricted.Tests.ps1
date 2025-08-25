Describe "Maester/Entra" -Tag "Governance", "Entra", "Security" {
    It "MT.1070: Restrict device join to selected users/groups or none." -Tag "MT.1070" {
        $result = Test-MtEntraDeviceJoinRestricted
        $result | Should -Be $true -Because "Device join should be restricted to prevent unauthorized devices from accessing organizational resources."
    }
}
