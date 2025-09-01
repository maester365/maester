Describe "Maester/Intune" -Tag "Maester", "Intune" {
    It "MT.1053: Ensure intune device clean-up rule is configured" -Tag "MT.1053" {
        $result = Test-MtManagedDeviceCleanupSettings
        if ($null -ne $result) {
            $result | Should -Be $true -Because "automatic device clean-up rule is configured."
        }
    }

    It "MT.1054: Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'" -Tag "MT.1054" {
        $result = Test-MtDeviceComplianceSettings
        if ($null -ne $result) {
            $result | Should -Be $true -Because "built-in device compliance policy marks devices with no policy assigned as 'Not compliant'."
        }
    }
}
