# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.156", "EXO", "Security", "All" {
    It "ORCA.156: Safe Links Policies are tracking when user clicks on safe links." {
        $result = Test-ORCA156

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links Policies are tracking when user clicks on safe links."
        }
    }
}
