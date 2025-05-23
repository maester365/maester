# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.158", "EXO", "Security", "All" {
    It "ORCA.158: Safe Attachments is enabled for SharePoint and Teams." {
        $result = Test-ORCA158

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is enabled for SharePoint and Teams."
        }
    }
}
