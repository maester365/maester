# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.227", "EXO", "Security", "All" {
    It "ORCA.227: Each domain has a Safe Attachments policy applied to it." {
        $result = Test-ORCA227

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Attachments policy applied to it."
        }
    }
}
