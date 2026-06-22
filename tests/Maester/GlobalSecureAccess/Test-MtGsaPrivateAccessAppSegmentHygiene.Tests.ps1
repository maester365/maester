Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXX11: Entra Private Access application segments should avoid broad or risky destinations. See https://maester.dev/docs/tests/MT.XXX11" -Tag "MT.XXX11", "Preview" {
        $result = Test-MtGsaPrivateAccessAppSegmentHygiene

        if ($null -ne $result) {
            $result | Should -Be $true -Because "dnsSuffix, wildcard, single-label, and all-IP segments break least-privilege and can mask DNS gaps or break Kerberos SSO."
        }
    }
}
