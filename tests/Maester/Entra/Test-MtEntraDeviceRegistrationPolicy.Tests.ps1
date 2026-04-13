Describe "Maester/Entra" -Tag "Entra", "Device" {
    It "MT.1070: Restrict device join to selected users/groups or none." -Tag "MT.1070" {
        $result = Test-MtEntraDeviceJoinRestricted
        $result | Should -Be $true -Because "Device join should be restricted to prevent unauthorized devices from accessing organizational resources."
    }

    It "MT.1090: Global administrator role should not be added as local administrator on the device during Microsoft Entra join" -Tag "MT.1090" {
        $result = Test-MtDeviceRegistrationLocalAdminsGlobalAdmin
        $result | Should -Be $true -Because "Global administrator role should not be added as local administrator on the device during Microsoft Entra join."
    }

    It "MT.1091: Registering user should not be added as local administrator on the device during Microsoft Entra join" -Tag "MT.1091" {
        $result = Test-MtDeviceRegistrationLocalAdminsRegisteringUser
        $result | Should -Be $true -Because "Registering user should not be added as local administrator on the device during Microsoft Entra join."
    }
}
