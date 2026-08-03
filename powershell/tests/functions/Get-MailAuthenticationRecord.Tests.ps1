Describe 'Get-MailAuthenticationRecord' {
    BeforeEach {
        Clear-MtDnsCache

        Mock ConvertFrom-MailAuthenticationRecordSpf -ModuleName Maester {
            [PSCustomObject]@{
                terms = @()
            }
        }

        Mock Resolve-SPFRecord -ModuleName Maester {
            [PSCustomObject]@{
                IPAddress = '192.0.2.1'
            }
        }
    }

    It 'Does not pass Server to SPF lookup when DnsServerIpAddress is omitted' {
        Get-MailAuthenticationRecord -DomainName 'contoso.com' -Records SPF | Out-Null

        Should -Invoke Resolve-SPFRecord -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Name -eq 'contoso.com' -and -not $PSBoundParameters.ContainsKey('Server')
        }
    }

    It 'Does not pass Server to SPF lookup when DnsServerIpAddress is explicitly null' {
        { Get-MailAuthenticationRecord -DomainName 'contoso.com' -Records SPF -DnsServerIpAddress $null } | Should -Not -Throw

        Should -Invoke Resolve-SPFRecord -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Name -eq 'contoso.com' -and -not $PSBoundParameters.ContainsKey('Server')
        }
    }

    It 'Passes Server to SPF lookup when DnsServerIpAddress has a value' {
        Get-MailAuthenticationRecord -DomainName 'contoso.com' -Records SPF -DnsServerIpAddress '1.1.1.1' | Out-Null

        Should -Invoke Resolve-SPFRecord -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Name -eq 'contoso.com' -and $Server -eq '1.1.1.1'
        }
    }
}
