# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.226", "EXO", "Security" {
    It "ORCA.226: Each domain has a Safe Link policy applied to it." {
        $result = Test-ORCA226

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Link policy applied to it."
        }
    }
}
