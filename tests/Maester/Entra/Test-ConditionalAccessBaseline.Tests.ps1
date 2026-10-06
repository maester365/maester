Describe "Maester/Entra" -Tag "Maester", "CA" {
    It "MT.1012: At least one Conditional Access policy is configured to require MFA for risky sign-ins. See https://maester.dev/docs/tests/MT.1012" -Skip:( $EntraIDPlan -eq "P1" ) -Tag "MT.1012" {
        Test-MtCaMfaForRiskySignIn | Should -Be $true -Because "there is no policy that requires MFA for risky sign-ins"
    }
    It "MT.1013: At least one Conditional Access policy is configured to require new password when user risk is high. See https://maester.dev/docs/tests/MT.1013" -Skip:( $EntraIDPlan -eq "P1" ) -Tag "MT.1013" {
        Test-MtCaRequirePasswordChangeForHighUserRisk | Should -Be $true -Because "there is no policy that requires new password when user risk is high"
    }




    Context "Maester/Entra" -Tag "Entra", "License" {
        It "MT.1022: All users utilizing a P1 license should be licensed. See https://maester.dev/docs/tests/MT.1022" -Tag "MT.1022" {
            $LicenseReport = Test-MtCaLicenseUtilization -License "P1"
            $LicenseReport.TotalLicensesUtilized | Should -BeLessOrEqual $LicenseReport.EntitledLicenseCount -Because "this is the maximum number of user that can utilize a P1 license"
        }
        It "MT.1023: All users utilizing a P2 license should be licensed. See https://maester.dev/docs/tests/MT.1023" -Tag "MT.1023" {
            $LicenseReport = Test-MtCaLicenseUtilization -License "P2"
            $LicenseReport.TotalLicensesUtilized | Should -BeLessOrEqual $LicenseReport.EntitledLicenseCount -Because "this is the maximum number of user that can utilize a P2 license"
        }
    }
}

Describe "Maester/Entra" -Tag "Maester", "CA" {
    It "MT.1021: Security Defaults are enabled. See https://maester.dev/docs/tests/MT.1021" -Tag "MT.1021" {
        $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
        if ($EntraIDPlan -ne "Free") {
            Add-MtTestResultDetail -SkippedBecause LicensedEntraIDPremium
        } else {
            $SecurityDefaults = Invoke-MtGraphRequest -RelativeUri "policies/identitySecurityDefaultsEnforcementPolicy" -ApiVersion beta | Select-Object -ExpandProperty isEnabled

            if ($SecurityDefaults -eq $true) {
                $testResultMarkdown = "Well done. SecurityDefaults are On `n`n"
            } else {
                $testResultMarkdown = "SecurityDefaults are Off '$($SecurityDefaults)' `n`n"
            }
            $testDetailsMarkdown = "You should enable SecurityDefaults or configure Conditional Access."
            Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

            $SecurityDefaults | Should -Be $true -Because "Security Defaults are not enabled"
        }
    }
}
