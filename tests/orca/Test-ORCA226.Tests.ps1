# Generated on 03/04/2025 09:34:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA226", "EXO", "Security", "All" {
    It "ORCA226: Each domain has a Safe Link policy applied to it." {
        $result = Test-ORCA226

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Link policy applied to it."
        }
    }
}
