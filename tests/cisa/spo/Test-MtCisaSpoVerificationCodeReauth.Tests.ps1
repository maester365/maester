Describe "CISA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.3.3", "CISA.MS.SHAREPOINT.3.3", "CISA" {
    It "CISA.MS.SHAREPOINT.3.3: Reauthentication days for people who use a verification code SHALL be set to 30 days or less." {

        $result = Test-MtCisaSpoVerificationCodeReauth

        if ($null -ne $result) {
            $result | Should -Be $true -Because "verification code reauthentication is within 30 days."
        }
    }
}
