Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-06" {
    It "AD-DCOMP-06: No enabled computers should be stale for 180 days or more" {

        $result = Test-MtAdComputerStaleEnabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "stale enabled computers retain attackable directory credentials"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
