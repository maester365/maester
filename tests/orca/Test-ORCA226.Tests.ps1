# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.226", "EXO", "Security", "All" {
    It "ORCA.226: Each domain has a Safe Link policy applied to it." {
        $result = Test-ORCA226

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Link policy applied to it."
        }
    }
}
