Describe "Maester/Intune" -Tag "Maester", "Intune", "LAPS" {
    It "MT.1124: Ensure LAPS Configuration Policy is properly set" -Tag "MT.1124" {
        $result = Test-MtIntuneLAPSConfiguration
        if ($null -ne $result) {
            $result | Should -Be $true -Because "a LAPS Configuration policy is properly set in Intune."
        }
    }
}