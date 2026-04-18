Describe "Maester/Intune" -Tag "Maester", "Intune", "AppControl" {
    It "MT.1126: Ensure App Control for Business is enabled" -Tag "MT.1126" {
        $result = Test-MtIntuneAppControl
        if ($null -ne $result) {
            $result | Should -Be $true -Because "App Control for Business is enabled in Intune."
        }
    }
}