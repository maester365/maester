# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA109", "EXO", "Security", "All" {
    It "ORCA109: Allowed Senders" {
        $result = Get-ORCA109

        if($null -ne $result) {
            $result | Should -Be $true -Because "Senders are not being allow listed in an unsafe manner"
        }
    }
}
