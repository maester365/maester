Describe 'Test-MtCisSafeAttachment' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\..\Maester.psd1" -Force
        . "$PSScriptRoot\..\helpers\Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisSafeAttachment
    }

    BeforeEach {
        Mock Add-MtTestResultDetail -ModuleName Maester { }
    }

    It 'Reports <Expected> for a custom rule scoped to <Scope>' -ForEach @(
        @{ Scope = 'all recipients'; Domains = @(); Groups = @(); Users = @(); Expected = 'Pass' }
        @{ Scope = 'every accepted domain'; Domains = @('contoso.com', 'fabrikam.com'); Groups = @(); Users = @(); Expected = 'Pass' }
        @{ Scope = 'a group'; Domains = @(); Groups = @('All staff'); Users = @(); Expected = 'Pass' }
        @{ Scope = 'some accepted domains'; Domains = @('contoso.com'); Groups = @(); Users = @(); Expected = 'Fail' }
        @{ Scope = 'users'; Domains = @(); Groups = @(); Users = @('adele@contoso.com'); Expected = 'Fail' }
        @{ Scope = 'some accepted domains and users'; Domains = @('contoso.com'); Groups = @(); Users = @('adele@contoso.com'); Expected = 'Fail' }
        @{ Scope = 'every accepted domain and users'; Domains = @('contoso.com', 'fabrikam.com'); Groups = @(); Users = @('adele@contoso.com'); Expected = 'Investigate' }
        @{ Scope = 'a group and users'; Domains = @(); Groups = @('All staff'); Users = @('adele@contoso.com'); Expected = 'Investigate' }
    ) {
        $policy = [pscustomobject]@{ Name = 'Contoso'; Identity = 'Contoso'; Enable = $true; Action = 'Block'; QuarantineTag = 'AdminOnlyAccessPolicy' }
        $rule = [pscustomobject]@{ Identity = 'Contoso'; SafeAttachmentPolicy = 'Contoso'; State = 'Enabled'; Priority = 0; RecipientDomainIs = $Domains; SentToMemberOf = $Groups; SentTo = $Users }
        Mock Get-MtExo -ModuleName Maester {
            switch ($Request) {
                'SafeAttachmentPolicy' { $policy }
                'SafeAttachmentRule' { $rule }
                'AcceptedDomain' { [pscustomobject]@{ Name = 'contoso.com' }; [pscustomobject]@{ Name = 'fabrikam.com' } }
            }
        }

        Test-MtCisSafeAttachment | Should -Be ($Expected -eq 'Pass')

        $scopeResult = if ($Expected -eq 'Pass') { 'Pass' } else { 'Fail' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            [bool]$Investigate -eq ($Expected -eq 'Investigate') -and
            $Result -match "\| Rule scope \| [^\r\n]* $scopeResult \|" -and
            ($Expected -ne 'Investigate' -or $Result -match 'MC1546447')
        }
    }

    It 'Fails without investigation when another check also fails' {
        $policy = [pscustomobject]@{ Name = 'Contoso'; Identity = 'Contoso'; Enable = $false; Action = 'Block'; QuarantineTag = 'AdminOnlyAccessPolicy' }
        $rule = [pscustomobject]@{ Identity = 'Contoso'; SafeAttachmentPolicy = 'Contoso'; State = 'Enabled'; Priority = 0; RecipientDomainIs = @('contoso.com', 'fabrikam.com'); SentTo = @('adele@contoso.com') }
        Mock Get-MtExo -ModuleName Maester {
            switch ($Request) {
                'SafeAttachmentPolicy' { $policy }
                'SafeAttachmentRule' { $rule }
                'AcceptedDomain' { [pscustomobject]@{ Name = 'contoso.com' }; [pscustomobject]@{ Name = 'fabrikam.com' } }
            }
        }

        Test-MtCisSafeAttachment | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            -not [bool]$Investigate -and $Result -match 'does not match CIS recommendations'
        }
    }
}
