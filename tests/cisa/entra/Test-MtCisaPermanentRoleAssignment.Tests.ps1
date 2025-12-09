Describe "CISA" -Tag "MS.AAD", "MS.AAD.7.4", "CISA.MS.AAD.7.4", "CISA", "Security", "Entra ID P2" {
    It "CISA.MS.AAD.7.4: Permanent active role assignments SHALL NOT be allowed for highly privileged roles." {
        $result = Test-MtCisaPermanentRoleAssignment

        if ($null -ne $result) {
            $result | Should -Be $true -Because "no permanently active privileged role assignments exist."
        }
    }
}
