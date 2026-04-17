Describe "Maester/Intune" -Tag "Maester", "Intune", "ManagedInstaller" {
    It "MT.1203: Ensure Managed Installer Rules are configured correctly" -Tag "MT.1203" {
        $result = Test-MtIntuneManagedInstallerRules
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Managed Installer Rules are configured to enforce security."
        }
    }
}