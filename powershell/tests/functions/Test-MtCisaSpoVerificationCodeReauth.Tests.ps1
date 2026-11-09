BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisaSpoVerificationCodeReauth
}

Describe 'Test-MtCisaSpoVerificationCodeReauth' {
    BeforeEach {
        $script:SpoTenant = $null
        $script:TestResultMarkdown = $null
        $script:SkippedBecause = $null

        Mock -ModuleName Maester Get-MtSpo { return $script:SpoTenant }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause)

            $script:TestResultMarkdown = $Result
            $script:SkippedBecause = $SkippedBecause
        }
    }

    It 'evaluates reauthentication for <SharingCapability> sharing' -ForEach @(
        @{ SharingCapability = 'ExternalUserAndGuestSharing' }
        @{ SharingCapability = 'ExternalUserSharingOnly' }
        @{ SharingCapability = 'ExistingExternalUserSharingOnly' }
    ) {
        $script:SpoTenant = [pscustomobject]@{
            SharingCapability = $SharingCapability
            EmailAttestationRequired = $false
            EmailAttestationReAuthDays = 45
        }

        Test-MtCisaSpoVerificationCodeReauth | Should -BeFalse
        $script:SkippedBecause | Should -BeNullOrEmpty
        $script:TestResultMarkdown | Should -Match 'not properly configured'
    }

    It 'marks organization-only sharing as not applicable' {
        $script:SpoTenant = [pscustomobject]@{
            SharingCapability = 'Disabled'
            EmailAttestationRequired = $false
            EmailAttestationReAuthDays = 90
        }

        Test-MtCisaSpoVerificationCodeReauth | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotApplicable'
    }
}
