Describe 'Get-MtCisParkedDomainClassification' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Get-MtCisParkedDomainClassification

        function ConvertTo-TestDnsResult {
            param(
                [string]$Name,
                [string]$Type,
                [object[]]$Answers = @(),
                [string]$Status = 'Success'
            )
            [pscustomobject]@{ Name = $Name; Type = $Type; Status = $Status; Answers = $Answers; Error = $null }
        }
    }

    BeforeEach {
        $script:dnsResults = @{}
        Mock Resolve-MtDnsRecord -ModuleName Maester {
            $key = "$Type|$Name"
            if ($script:dnsResults.ContainsKey($key)) {
                return $script:dnsResults[$key]
            }
            return ConvertTo-TestDnsResult -Name $Name -Type $Type
        }
    }

    It 'classifies a deny-all domain with null MX and no other DNS use as parked' {
        $script:dnsResults['TXT|parked.example'] = ConvertTo-TestDnsResult -Name 'parked.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 -all'; Preference = $null }
        )
        $script:dnsResults['MX|parked.example'] = ConvertTo-TestDnsResult -Name 'parked.example' -Type MX -Answers @(
            [pscustomobject]@{ Value = '.'; Preference = 0 }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'parked.example'

        $result.Classification | Should -Be 'Parked'
        $result.IsParked | Should -BeTrue
    }

    It 'classifies a deny-all domain without MX or fallback addresses as parked' {
        $script:dnsResults['TXT|parked.example'] = ConvertTo-TestDnsResult -Name 'parked.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 -all'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'parked.example'

        $result.Classification | Should -Be 'Parked'
    }

    It 'classifies a softfail-only domain as parked so the audit can enforce hard fail' {
        $script:dnsResults['TXT|parked.example'] = ConvertTo-TestDnsResult -Name 'parked.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 ~all'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'parked.example'

        $result.Classification | Should -Be 'Parked'
        $result.SpfDeniesAll | Should -BeFalse
    }

    It 'does not accept a parked hard-fail record with a trailing modifier' {
        $script:dnsResults['TXT|parked.example'] = ConvertTo-TestDnsResult -Name 'parked.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 -all exp=explain.example'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'parked.example'

        $result.Classification | Should -Be 'Parked'
        $result.SpfDeniesAll | Should -BeFalse
    }

    It 'does not classify a domain with fallback address records as parked' {
        $script:dnsResults['TXT|mail.example'] = ConvertTo-TestDnsResult -Name 'mail.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 -all'; Preference = $null }
        )
        $script:dnsResults['A|mail.example'] = ConvertTo-TestDnsResult -Name 'mail.example' -Type A -Answers @(
            [pscustomobject]@{ Value = '192.0.2.10'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'mail.example'

        $result.Classification | Should -Be 'NotSending'
        $result.IsParked | Should -BeFalse
    }

    It 'leaves a domain unknown when a receiving DNS lookup is incomplete' -ForEach @(
        @{ Type = 'MX'; Status = 'Error' }
        @{ Type = 'MX'; Status = 'NotAvailable' }
        @{ Type = 'A'; Status = 'Error' }
        @{ Type = 'A'; Status = 'NotAvailable' }
        @{ Type = 'AAAA'; Status = 'Error' }
        @{ Type = 'AAAA'; Status = 'NotAvailable' }
        @{ Type = 'CNAME'; Status = 'Error' }
        @{ Type = 'CNAME'; Status = 'NotAvailable' }
    ) {
        $script:dnsResults['TXT|uncertain.example'] = ConvertTo-TestDnsResult -Name 'uncertain.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 -all'; Preference = $null }
        )
        $script:dnsResults["$Type|uncertain.example"] = ConvertTo-TestDnsResult -Name 'uncertain.example' -Type $Type -Status $Status

        $result = Get-MtCisParkedDomainClassification -DomainName 'uncertain.example'

        $result.Classification | Should -Be 'Unknown'
        $result.IsParked | Should -BeFalse
        $result.Reason | Should -Match 'Receiving or other domain use could not be ruled out'
    }

    It 'classifies a configured DKIM domain as sending' {
        $config = [pscustomobject]@{ Domain = 'sender.example'; Enabled = $false }

        $result = Get-MtCisParkedDomainClassification -DomainName 'sender.example' -DkimSigningConfigs @($config)

        $result.Classification | Should -Be 'Sending'
    }

    It 'separates a signing configuration from published selector evidence for a parked override' {
        $config = [pscustomobject]@{ Domain = 'parked.example'; Enabled = $false }

        $result = Get-MtCisParkedDomainClassification -DomainName 'parked.example' -DkimSigningConfigs @($config) -ParkedDomains 'parked.example'

        $result.Classification | Should -Be 'Parked'
        $result.DkimEvidence | Should -BeTrue
        $result.DkimSelectorRecordEvidence | Should -BeFalse
        $result.DkimSelectorLookupsComplete | Should -BeTrue
    }

    It 'classifies a domain with a published standard DKIM selector as sending' {
        $script:dnsResults['TXT|sender.example'] = ConvertTo-TestDnsResult -Name 'sender.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 -all'; Preference = $null }
        )
        $script:dnsResults['CNAME|selector1._domainkey.sender.example'] = ConvertTo-TestDnsResult -Name 'selector1._domainkey.sender.example' -Type CNAME -Answers @(
            [pscustomobject]@{ Value = 'selector1-sender._domainkey.example.onmicrosoft.com'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'sender.example'

        $result.Classification | Should -Be 'Sending'
        $result.DkimEvidence | Should -BeTrue
        $result.DkimSelectorRecordEvidence | Should -BeTrue
    }

    It 'applies an explicit parked override while retaining conflicting DKIM evidence' {
        $script:dnsResults['CNAME|selector1._domainkey.sender.example'] = ConvertTo-TestDnsResult -Name 'selector1._domainkey.sender.example' -Type CNAME -Answers @(
            [pscustomobject]@{ Value = 'selector1-sender._domainkey.example.onmicrosoft.com'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'sender.example' -ParkedDomains 'SENDER.EXAMPLE.'

        $result.Classification | Should -Be 'Parked'
        $result.IsOverride | Should -BeTrue
        $result.DkimEvidence | Should -BeTrue
        $result.DkimSelectorRecordEvidence | Should -BeTrue
    }

    It 'classifies a domain with SPF mechanisms as sending' {
        $script:dnsResults['TXT|sender.example'] = ConvertTo-TestDnsResult -Name 'sender.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 include:spf.example.net -all'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'sender.example'

        $result.Classification | Should -Be 'Sending'
    }

    It 'treats an unqualified all mechanism as a sending signal' {
        $script:dnsResults['TXT|sender.example'] = ConvertTo-TestDnsResult -Name 'sender.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 all'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'sender.example'

        $result.Classification | Should -Be 'Sending'
    }

    It 'leaves a domain unknown when SPF is missing' {
        $result = Get-MtCisParkedDomainClassification -DomainName 'unknown.example'

        $result.Classification | Should -Be 'Unknown'
        $result.IsParked | Should -BeFalse
    }

    It 'leaves redirect-only SPF unknown until the redirect target is evaluated' {
        $script:dnsResults['TXT|unknown.example'] = ConvertTo-TestDnsResult -Name 'unknown.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 redirect=_spf.example.net'; Preference = $null }
        )

        $result = Get-MtCisParkedDomainClassification -DomainName 'unknown.example'

        $result.Classification | Should -Be 'Unknown'
        $result.SpfDeniesAll | Should -BeFalse
    }

    It 'exposes incomplete selector lookup state when a parked override is supplied' {
        $script:dnsResults['TXT|unknown.example'] = ConvertTo-TestDnsResult -Name 'unknown.example' -Type TXT -Answers @(
            [pscustomobject]@{ Value = 'v=spf1 -all'; Preference = $null }
        )
        $script:dnsResults['CNAME|selector1._domainkey.unknown.example'] = ConvertTo-TestDnsResult -Name 'selector1._domainkey.unknown.example' -Type CNAME -Status Error

        $result = Get-MtCisParkedDomainClassification -DomainName 'unknown.example' -ParkedDomains 'unknown.example'

        $result.Classification | Should -Be 'Parked'
        $result.DkimSelectorLookupsComplete | Should -BeFalse
    }
}
