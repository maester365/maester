# Legacy Pester fixture: a stale copy of an early CISA wrapper, written before the "CISA."
# prefix was added. MS.AAD.7.1 is a previous ID of CISA.MS.AAD.7.1, so 3.0 supersedes it
# through Maester.LegacyIds.json.
Describe "CISA" -Tag "MS.AAD", "MS.AAD.7.1", "CISA", "Entra ID Free" {
    It "MS.AAD.7.1: A minimum of two users and a maximum of eight users SHALL be provisioned with the Global Administrator role." {
        $result = Test-MtCisaGlobalAdminCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "two or more and eight or fewer Global Administrators exist."
        }
    }
}
