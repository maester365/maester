# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA226", "EXO", "Security", "All" {
    It "ORCA226: Safe Links Policy Rules" {
        $result = Test-ORCA226

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Link policy applied to it"
        }
    }
}
