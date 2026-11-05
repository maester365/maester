Describe 'Resolve-MtDnsRecord with Resolve-DnsName' -Skip:(-not $IsWindows) {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Resolve-MtDnsRecord
    }

    BeforeEach {
        Clear-MtDnsCache
        Mock Resolve-DnsName -ModuleName Maester {}
    }

    It 'normalizes MX answers and their preference' {
        Mock Resolve-DnsName -ModuleName Maester {
            [pscustomobject]@{
                Section      = 'Answer'
                Type         = 'MX'
                NameExchange = 'mail.example.com'
                Preference   = 10
            }
        }

        $result = Resolve-MtDnsRecord -Name 'example.com' -Type MX

        $result.Status | Should -Be 'Success'
        $result.Answers.Count | Should -Be 1
        $result.Answers[0].Value | Should -Be 'mail.example.com'
        $result.Answers[0].Preference | Should -Be 10
    }

    It 'joins TXT character strings into one record' {
        Mock Resolve-DnsName -ModuleName Maester {
            [pscustomobject]@{
                Section = 'Answer'
                Type    = 'TXT'
                Strings = @('v=spf1 ', '-all')
            }
        }

        $result = Resolve-MtDnsRecord -Name 'example.com' -Type TXT

        $result.Answers[0].Value | Should -Be 'v=spf1 -all'
    }

    It 'keeps an empty TXT record without discarding other answers' {
        Mock Resolve-DnsName -ModuleName Maester {
            @(
                [pscustomobject]@{ Section = 'Answer'; Type = 'TXT'; Strings = @('') }
                [pscustomobject]@{ Section = 'Answer'; Type = 'TXT'; Strings = @('v=spf1 -all') }
            )
        }

        $result = Resolve-MtDnsRecord -Name 'example.com' -Type TXT

        $result.Status | Should -Be 'Success'
        $result.Answers.Count | Should -Be 2
        $result.Answers.Value | Should -Contain ''
        $result.Answers.Value | Should -Contain 'v=spf1 -all'
    }

    It 'caches results by case-insensitive DNS name and record type' {
        Mock Resolve-DnsName -ModuleName Maester {
            [pscustomobject]@{ Section = 'Answer'; Type = 'TXT'; Strings = @('v=spf1 -all') }
        }

        $first = Resolve-MtDnsRecord -Name 'Example.com.' -Type TXT
        $second = Resolve-MtDnsRecord -Name 'example.COM' -Type TXT

        $second.Answers[0].Value | Should -Be $first.Answers[0].Value
        Should -Invoke Resolve-DnsName -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Name -eq 'Example.com.' -and $Type -eq 'TXT'
        }

        Clear-MtDnsCache
        $null = Resolve-MtDnsRecord -Name 'example.com' -Type TXT

        Should -Invoke Resolve-DnsName -ModuleName Maester -Exactly 2 -ParameterFilter {
            $Type -eq 'TXT'
        }
    }

    It 'returns success with no answers when the record type is absent' {
        $result = Resolve-MtDnsRecord -Name 'example.com' -Type MX

        $result.Status | Should -Be 'Success'
        $result.Answers.Count | Should -Be 0
    }

    It 'distinguishes a missing DNS name from a resolver failure' {
        Mock Resolve-DnsName -ModuleName Maester {
            throw [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('The DNS name does not exist.'),
                'DNS_ERROR_RCODE_NAME_ERROR',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $null
            )
        }

        $missing = Resolve-MtDnsRecord -Name 'missing.example' -Type MX

        Mock Resolve-DnsName -ModuleName Maester {
            throw [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('The DNS server is unavailable.'),
                'DNS_ERROR_RCODE_SERVER_FAILURE',
                [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                $null
            )
        }

        $unavailable = Resolve-MtDnsRecord -Name 'example.com' -Type MX

        $missing.Status | Should -Be 'NXDomain'
        $unavailable.Status | Should -Be 'Error'
    }
}

Describe 'Resolve-MtDnsRecord with Resolve-Dns' -Skip:$IsWindows {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Resolve-MtDnsRecord

        $script:createdDnsStub = & (Get-Module Maester) {
            if (-not (Get-Command -Name 'Resolve-Dns' -ErrorAction SilentlyContinue)) {
                Set-Item -Path 'Function:script:Resolve-Dns' -Value {
                    [CmdletBinding()]
                    param($Query, $QueryType, $NameServer)
                    throw "Resolve-Dns was called without a mock (query '$Query', type '$QueryType', server '$NameServer')."
                }
                $true
            } else {
                $false
            }
        }
    }

    AfterAll {
        if ($script:createdDnsStub) {
            & (Get-Module Maester) { Remove-Item -Path 'Function:script:Resolve-Dns' }
        }
    }

    BeforeEach {
        Clear-MtDnsCache
        Mock Resolve-Dns -ModuleName Maester {}
    }

    It 'normalizes MX answers and their preference' {
        Mock Resolve-Dns -ModuleName Maester {
            [pscustomobject]@{
                HasError = $false
                Header   = [pscustomobject]@{ ResponseCode = 'NoError' }
                Answers  = @([pscustomobject]@{ RecordType = 'MX'; Exchange = 'mail.example.com'; Preference = 10 })
            }
        }

        $result = Resolve-MtDnsRecord -Name 'example.com' -Type MX

        $result.Status | Should -Be 'Success'
        $result.Answers.Count | Should -Be 1
        $result.Answers[0].Value | Should -Be 'mail.example.com'
        $result.Answers[0].Preference | Should -Be 10
        Should -Invoke -ModuleName Maester Resolve-Dns -Exactly 1 -ParameterFilter {
            $Query -eq 'example.com' -and $QueryType -eq 'MX'
        }
    }

    It 'joins TXT character strings into one record' {
        Mock Resolve-Dns -ModuleName Maester {
            [pscustomobject]@{
                HasError = $false
                Header   = [pscustomobject]@{ ResponseCode = 'NoError' }
                Answers  = @([pscustomobject]@{ RecordType = 'TXT'; Text = @('v=spf1 ', '-all') })
            }
        }

        $result = Resolve-MtDnsRecord -Name 'example.com' -Type TXT

        $result.Answers[0].Value | Should -Be 'v=spf1 -all'
    }

    It 'keeps an empty TXT record without discarding other answers' {
        Mock Resolve-Dns -ModuleName Maester {
            [pscustomobject]@{
                HasError = $false
                Header   = [pscustomobject]@{ ResponseCode = 'NoError' }
                Answers  = @(
                    [pscustomobject]@{ RecordType = 'TXT'; Text = @('') }
                    [pscustomobject]@{ RecordType = 'TXT'; Text = @('v=spf1 -all') }
                )
            }
        }

        $result = Resolve-MtDnsRecord -Name 'example.com' -Type TXT

        $result.Status | Should -Be 'Success'
        $result.Answers.Count | Should -Be 2
        $result.Answers.Value | Should -Contain ''
        $result.Answers.Value | Should -Contain 'v=spf1 -all'
    }

    It 'caches results by case-insensitive DNS name and record type' {
        Mock Resolve-Dns -ModuleName Maester {
            [pscustomobject]@{
                HasError = $false
                Header   = [pscustomobject]@{ ResponseCode = 'NoError' }
                Answers  = @([pscustomobject]@{ RecordType = 'TXT'; Text = @('v=spf1 -all') })
            }
        }

        $first = Resolve-MtDnsRecord -Name 'Example.com.' -Type TXT
        $second = Resolve-MtDnsRecord -Name 'example.COM' -Type TXT

        $second.Answers[0].Value | Should -Be $first.Answers[0].Value
        Should -Invoke Resolve-Dns -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Query -eq 'Example.com.' -and $QueryType -eq 'TXT'
        }

        Clear-MtDnsCache
        $null = Resolve-MtDnsRecord -Name 'example.com' -Type TXT

        Should -Invoke Resolve-Dns -ModuleName Maester -Exactly 2 -ParameterFilter {
            $QueryType -eq 'TXT'
        }
    }

    It 'distinguishes a missing DNS name from a resolver failure' {
        Mock Resolve-Dns -ModuleName Maester {
            [pscustomobject]@{
                HasError = $true
                Header   = [pscustomobject]@{ ResponseCode = 'NotExistentDomain' }
                ErrorMessage = 'Non-Existent Domain'
                Answers  = @()
            }
        }

        $missing = Resolve-MtDnsRecord -Name 'missing.example' -Type MX

        Mock Resolve-Dns -ModuleName Maester {
            [pscustomobject]@{
                HasError = $true
                Header   = [pscustomobject]@{ ResponseCode = 'ServerFailure' }
                ErrorMessage = 'Server Failure'
                Answers  = @()
            }
        }

        $unavailable = Resolve-MtDnsRecord -Name 'example.com' -Type MX

        $missing.Status | Should -Be 'NXDomain'
        $unavailable.Status | Should -Be 'Error'
        $unavailable.Error | Should -Be 'Server Failure'
    }
}
