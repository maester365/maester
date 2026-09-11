BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'DKIM checks with no signing configuration' -ForEach @(
    @{ CommandName = 'Test-MtCisDkim' }
    @{ CommandName = 'Test-MtCisaDkim' }
) {
    BeforeEach {
        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
        Mock -ModuleName Maester Get-MailAuthenticationRecord {
            throw 'DNS lookup should not be attempted without a DKIM signing configuration'
        }
    }

    It '<CommandName> handles domain <DomainName> correctly' -ForEach @(
        @{
            DomainName                = 'contoso.onmicrosoft.com'
            InitialDomain             = $true
            IsCoexistenceDomain       = $false
            SendingFromDomainDisabled = $false
            # Test-MtCisDkim (CIS v7.0.0) excludes the initial (MOERA) domain from the audit entirely,
            # while Test-MtCisaDkim still auto-passes it.
            ExpectedResultByCommand   = @{
                'Test-MtCisDkim'  = $null
                'Test-MtCisaDkim' = $true
            }
        }
        @{
            DomainName                = 'secondary.onmicrosoft.com'
            InitialDomain             = $false
            IsCoexistenceDomain       = $false
            SendingFromDomainDisabled = $false
            ExpectedResultByCommand   = @{
                'Test-MtCisDkim'  = $false
                'Test-MtCisaDkim' = $false
            }
        }
        @{
            DomainName                = 'parked.example'
            InitialDomain             = $false
            IsCoexistenceDomain       = $false
            SendingFromDomainDisabled = $true
            ExpectedResultByCommand   = @{
                'Test-MtCisDkim'  = $null
                'Test-MtCisaDkim' = $null
            }
        }
        @{
            DomainName                = 'contoso.mail.onmicrosoft.com'
            InitialDomain             = $false
            IsCoexistenceDomain       = $true
            SendingFromDomainDisabled = $false
            # Test-MtCisDkim (CIS v7.0.0) excludes coexistence domains from the audit entirely,
            # while Test-MtCisaDkim still evaluates them (and fails, since no signing config exists).
            ExpectedResultByCommand   = @{
                'Test-MtCisDkim'  = $null
                'Test-MtCisaDkim' = $false
            }
        }
        @{
            DomainName                = 'contoso.mail.onmicrosoft.com'
            InitialDomain             = $false
            IsCoexistenceDomain       = $true
            SendingFromDomainDisabled = $true
            ExpectedResultByCommand   = @{
                'Test-MtCisDkim'  = $null
                'Test-MtCisaDkim' = $null
            }
        }
        @{
            DomainName                = 'contoso.com'
            InitialDomain             = $false
            IsCoexistenceDomain       = $false
            SendingFromDomainDisabled = $false
            ExpectedResultByCommand   = @{
                'Test-MtCisDkim'  = $false
                'Test-MtCisaDkim' = $false
            }
        }
    ) {
        Mock -ModuleName Maester Get-MtExo {
            if ($Request -eq 'AcceptedDomain') {
                return [PSCustomObject]@{
                    DomainName                = $DomainName
                    InitialDomain             = $InitialDomain
                    IsCoexistenceDomain       = $IsCoexistenceDomain
                    SendingFromDomainDisabled = $SendingFromDomainDisabled
                }
            }

            return @()
        }

        $expectedResult = $ExpectedResultByCommand[$CommandName]

        $result = & $CommandName
        if ($null -eq $expectedResult) {
            $result | Should -BeNullOrEmpty
        } else {
            $result | Should -Be $expectedResult
        }
        Should -Invoke Get-MailAuthenticationRecord -ModuleName Maester -Exactly 0
    }
}
