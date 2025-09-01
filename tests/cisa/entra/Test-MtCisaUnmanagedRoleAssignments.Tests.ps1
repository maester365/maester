Describe "CISA" -Tag "MS.AAD", "MS.AAD.7.5", "CISA.MS.AAD.7.5", "CISA", "Security", "Entra ID P2" {
    It "CISA.MS.AAD.7.5: Provisioning users to highly privileged roles SHALL NOT occur outside of a PAM system." {
        $result = Test-MtCisaUnmanagedRoleAssignment

        if ($null -ne $result) {
            $result | Should -Be $true -Because "no unmanaged active role assignments exist."
        }
    }
}
