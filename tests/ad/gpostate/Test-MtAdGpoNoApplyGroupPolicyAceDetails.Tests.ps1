Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-11" {
    It "AD-GPOREP-11: GPO no-apply Group Policy ACE details should be investigated" {
        $result = Test-MtAdGpoNoApplyGroupPolicyAceDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
