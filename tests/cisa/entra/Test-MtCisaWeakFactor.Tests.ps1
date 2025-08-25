Describe "CISA" -Tag "MS.AAD", "MS.AAD.3.5", "CISA.MS.AAD.3.5", "CISA", "Security", "Entra ID P1" {
    It "CISA.MS.AAD.3.5: The authentication methods SMS, Voice Call, and Email One-Time Passcode (OTP) SHALL be disabled." {
        $result = Test-MtCisaWeakFactor

        if ($null -ne $result) {
            $result | Should -Be $true -Because "all weak authentication methods are disabled."
        }
    }
}
