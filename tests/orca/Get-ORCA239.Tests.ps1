# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA239", "EXO", "Security", "All" {
    It "ORCA239: Built-in Protection" {
        $result = Get-ORCA239

        if($null -ne $result) {
            $result | Should -Be $true -Because "No exclusions for the built-in protection policies"
        }
    }
}
