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
            # Both commands exclude coexistence domains from the audit entirely.
            ExpectedResultByCommand   = @{
                'Test-MtCisDkim'  = $null
                'Test-MtCisaDkim' = $null
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

Describe 'DKIM checks for coexistence domains with a signing configuration' -ForEach @(
    @{ CommandName = 'Test-MtCisDkim' }
    @{ CommandName = 'Test-MtCisaDkim' }
) {
    BeforeEach {
        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
        Mock -ModuleName Maester Get-MailAuthenticationRecord {
            throw 'DNS lookup should not be attempted for a coexistence domain'
        }
    }

    It '<CommandName> skips coexistence domain when DKIM is <State>' -ForEach @(
        @{ State = 'enabled'; Enabled = $true }
        @{ State = 'disabled'; Enabled = $false }
    ) {
        Mock -ModuleName Maester Get-MtExo {
            if ($Request -eq 'AcceptedDomain') {
                return [PSCustomObject]@{
                    DomainName                = 'contoso.mail.onmicrosoft.com'
                    InitialDomain             = $false
                    IsCoexistenceDomain       = $true
                    SendingFromDomainDisabled = $false
                }
            }

            return [PSCustomObject]@{
                Domain                     = 'contoso.mail.onmicrosoft.com'
                Enabled                    = $Enabled
                RotateOnDate               = (Get-Date).AddDays(-1)
                SelectorBeforeRotateOnDate = 'selector1'
                SelectorAfterRotateOnDate  = 'selector2'
            }
        }

        & $CommandName | Should -BeNullOrEmpty
        Should -Invoke Get-MailAuthenticationRecord -ModuleName Maester -Exactly 0
    }
}
