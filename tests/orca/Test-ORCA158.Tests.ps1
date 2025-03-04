# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA158", "EXO", "Security", "All" {
    It "ORCA158: Safe Attachments is enabled for SharePoint and Teams." {
        $result = Test-ORCA158

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is enabled for SharePoint and Teams."
        }
    }
}
