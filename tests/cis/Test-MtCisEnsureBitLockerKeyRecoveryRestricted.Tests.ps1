Describe "CIS" -Tag "CIS.M365.5.1.4.6", "L2", "CIS E3 Level 2", "CIS E3", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "CIS M365 v6.0.1" {
    It "CIS.M365.5.1.4.6: Ensure users are restricted from recovering BitLocker keys" {

        $result = Test-MtCisEnsureBitLockerKeyRecoveryRestricted

        if ($null -ne $result) {
            $result | Should -Be $true -Because "non-admin users are restricted from recovering BitLocker keys for their owned devices."
        }
    }
}
