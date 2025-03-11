# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA158", "EXO", "Security", "All" {
    It "ORCA158: Safe Attachments is enabled for SharePoint and Teams." {
        $result = Test-ORCA158

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is enabled for SharePoint and Teams."
        }
    }
}
