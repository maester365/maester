Describe "CISA" -Tag "MS.AAD", "MS.AAD.7.1", "CISA.MS.AAD.7.1", "CISA", "Security", "Entra ID Free" {
    It "CISA.MS.AAD.7.1: A minimum of two users and a maximum of eight users SHALL be provisioned with the Global Administrator role." {
        $result = Test-MtCisaGlobalAdminCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "two or more and eight or fewer Global Administrators exist."
        }
    }
}
