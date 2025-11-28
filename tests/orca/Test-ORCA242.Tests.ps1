# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.242", "EXO", "Security" {
    It "ORCA.242: Important protection alerts responsible for AIR activities are enabled." {
        $result = Test-ORCA242

        if($null -ne $result) {
            $result | Should -Be $true -Because "Important protection alerts responsible for AIR activities are enabled."
        }
    }
}
