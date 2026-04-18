Describe "Maester/Intune" -Tag "Maester", "Intune", "ASR" {
    It "MT.1125: Ensure ASR Rules are configured correctly" -Tag "MT.1125" {
        $result = Test-MtIntuneASRRules
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Attack Surface Reduction (ASR) Rules are configured to block threats."
        }
    }
}