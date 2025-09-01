# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.158", "EXO", "Security" {
    It "ORCA.158: Safe Attachments is enabled for SharePoint and Teams." {
        $result = Test-ORCA158

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is enabled for SharePoint and Teams."
        }
    }
}
