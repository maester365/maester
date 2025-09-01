Describe "CISA" -Tag "MS.AAD", "MS.AAD.7.7", "CISA.MS.AAD.7.7", "CISA", "Security", "Entra ID P2" {
    It "CISA.MS.AAD.7.7: Eligible and Active highly privileged role assignments SHALL trigger an alert." {
        $result = Test-MtCisaAssignmentNotification

        if ($null -ne $result) {
            $result | Should -Be $true -Because "highly privileged roles are set to notify on assignment."
        }
    }
}
