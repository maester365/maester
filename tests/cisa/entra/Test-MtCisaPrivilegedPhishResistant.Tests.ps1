Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.6", "CISA", "Security", "All", "Entra ID P1" {
    It "MS.AAD.3.6: Phishing-resistant MFA SHALL be required for highly privileged roles." {
        $result = Test-MtCisaPrivilegedPhishResistant

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled conditional access policy for highly privileged roles should require phishing resistant MFA."
        }
    }
}