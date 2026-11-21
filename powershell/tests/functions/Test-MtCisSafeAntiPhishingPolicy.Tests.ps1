Describe 'Test-MtCisSafeAntiPhishingPolicy' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\..\Maester.psd1" -Force
        . "$PSScriptRoot\..\helpers\Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisSafeAntiPhishingPolicy

        # Every CIS setting is met, so the rule scope decides the result.
        $script:compliantSettings = @{
            Enabled                             = $true
            PhishThresholdLevel                 = 3
            EnableTargetedUserProtection        = $true
            TargetedUsersToProtect              = @('Executive;executive@contoso.com')
            EnableOrganizationDomainsProtection = $true
            EnableMailboxIntelligence           = $true
            EnableMailboxIntelligenceProtection = $true
            EnableSpoofIntelligence             = $true
            TargetedUserProtectionAction        = 'Quarantine'
            TargetedDomainProtectionAction      = 'Quarantine'
            MailboxIntelligenceProtectionAction = 'Quarantine'
            EnableFirstContactSafetyTips        = $true
            EnableSimilarUsersSafetyTips        = $true
            EnableSimilarDomainsSafetyTips      = $true
            EnableUnusualCharactersSafetyTips   = $true
            HonorDmarcPolicy                    = $true
        }
    }

    BeforeEach {
        Mock Add-MtTestResultDetail -ModuleName Maester { }
    }

    It 'Reports <Expected> for a rule scoped to <Scope>' -ForEach @(
        @{ Scope = 'all recipients'; Domains = @(); Groups = @(); Users = @(); Expected = 'Pass' }
        @{ Scope = 'every accepted domain'; Domains = @('contoso.com', 'fabrikam.com'); Groups = @(); Users = @(); Expected = 'Pass' }
        @{ Scope = 'a group'; Domains = @(); Groups = @('All staff'); Users = @(); Expected = 'Pass' }
        @{ Scope = 'some accepted domains'; Domains = @('contoso.com'); Groups = @(); Users = @(); Expected = 'Fail' }
        @{ Scope = 'users'; Domains = @(); Groups = @(); Users = @('adele@contoso.com'); Expected = 'Fail' }
        @{ Scope = 'some accepted domains and users'; Domains = @('contoso.com'); Groups = @(); Users = @('adele@contoso.com'); Expected = 'Fail' }
        @{ Scope = 'every accepted domain and users'; Domains = @('contoso.com', 'fabrikam.com'); Groups = @(); Users = @('adele@contoso.com'); Expected = 'Investigate' }
        @{ Scope = 'a group and users'; Domains = @(); Groups = @('All staff'); Users = @('adele@contoso.com'); Expected = 'Investigate' }
    ) {
        $policy = [pscustomobject](@{ Name = 'Contoso'; Identity = 'Contoso' } + $script:compliantSettings)
        $rule = [pscustomobject]@{ AntiPhishPolicy = 'Contoso'; State = 'Enabled'; Priority = 0; RecipientDomainIs = $Domains; SentToMemberOf = $Groups; SentTo = $Users }
        Mock Get-MtExo -ModuleName Maester {
            switch ($Request) {
                'AntiPhishPolicy' { $policy }
                'AntiPhishRule' { $rule }
                'AcceptedDomain' { [pscustomobject]@{ Name = 'contoso.com' }; [pscustomobject]@{ Name = 'fabrikam.com' } }
            }
        }

        Test-MtCisSafeAntiPhishingPolicy | Should -Be ($Expected -eq 'Pass')

        $scopeResult = if ($Expected -eq 'Pass') { 'Pass' } else { 'Fail' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            [bool]$Investigate -eq ($Expected -eq 'Investigate') -and
            $Result -match "\| Contoso \| Enabled matching rule and scope \| [^\r\n]* $scopeResult \|" -and
            ($Expected -ne 'Investigate' -or $Result -match 'MC1546447')
        }
    }

    It 'Passes without investigation when another policy meets every check' {
        $executivePolicy = [pscustomobject](@{ Name = 'Executives'; Identity = 'Executives' } + $script:compliantSettings)
        $tenantPolicy = [pscustomobject](@{ Name = 'Contoso'; Identity = 'Contoso' } + $script:compliantSettings)
        Mock Get-MtExo -ModuleName Maester {
            switch ($Request) {
                'AntiPhishPolicy' { $executivePolicy; $tenantPolicy }
                'AntiPhishRule' {
                    [pscustomobject]@{ AntiPhishPolicy = 'Executives'; State = 'Enabled'; Priority = 0; RecipientDomainIs = @('contoso.com', 'fabrikam.com'); SentTo = @('adele@contoso.com') }
                    [pscustomobject]@{ AntiPhishPolicy = 'Contoso'; State = 'Enabled'; Priority = 1; RecipientDomainIs = @('contoso.com', 'fabrikam.com') }
                }
                'AcceptedDomain' { [pscustomobject]@{ Name = 'contoso.com' }; [pscustomobject]@{ Name = 'fabrikam.com' } }
            }
        }

        Test-MtCisSafeAntiPhishingPolicy | Should -BeTrue

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            -not [bool]$Investigate -and $Result.StartsWith('Well done.')
        }
    }
}