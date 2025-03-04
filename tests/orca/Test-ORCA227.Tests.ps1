# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA227", "EXO", "Security", "All" {
    It "ORCA227: Each domain has a Safe Attachments policy applied to it." {
        $result = Test-ORCA227

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Attachments policy applied to it."
        }
    }
}
