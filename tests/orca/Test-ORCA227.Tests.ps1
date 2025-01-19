# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA227", "EXO", "Security", "All" {
    It "ORCA227: Safe Attachments Policy Rules" {
        $result = Test-ORCA227

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Attachments policy applied to it"
        }
    }
}
