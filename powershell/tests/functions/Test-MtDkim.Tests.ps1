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

    It '<CommandName> passes the initial onmicrosoft.com domain' {
        Mock -ModuleName Maester Get-MtExo {
            if ($Request -eq 'AcceptedDomain') {
                return [PSCustomObject]@{
                    DomainName               = 'contoso.onmicrosoft.com'
                    InitialDomain            = $true
                    SendingFromDomainDisabled = $false
                }
            }

            return @()
        }

        & $CommandName | Should -BeTrue
        Should -Invoke Get-MailAuthenticationRecord -ModuleName Maester -Exactly 0
    }

    It '<CommandName> fails a secondary onmicrosoft.com domain' {
        Mock -ModuleName Maester Get-MtExo {
            if ($Request -eq 'AcceptedDomain') {
                return [PSCustomObject]@{
                    DomainName               = 'secondary.onmicrosoft.com'
                    InitialDomain            = $false
                    SendingFromDomainDisabled = $false
                }
            }

            return @()
        }

        & $CommandName | Should -BeFalse
        Should -Invoke Get-MailAuthenticationRecord -ModuleName Maester -Exactly 0
    }
}
