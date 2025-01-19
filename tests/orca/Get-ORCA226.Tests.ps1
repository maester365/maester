# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA226", "EXO", "Security", "All" {
    It "ORCA226: Safe Links Policy Rules" {
        $result = Get-ORCA226

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Link policy applied to it"
        }
    }
}
