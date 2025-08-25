Describe "CIS" -Tag "Security", "CIS", "CIS M365 v5.0.0" {
    It "CIS.M365.8.1.1: (L2) Ensure external file sharing in Teams is enabled for only approved cloud storage services" -Tag "CIS.M365.8.1.1", "CIS E3 Level 2" {

        $result = Test-MtCisThirdPartyFileSharing

        if ($null -ne $result) {
            $result | Should -Be $true -Because "file sharing with third-party cloud services is disabled."
        }
    }
}
