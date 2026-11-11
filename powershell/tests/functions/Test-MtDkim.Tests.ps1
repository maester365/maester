BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    # Check functions that became native tests are not exported.
    Use-MtModuleFunction -Name Test-MtCisaDkim, Test-MtCisDkim
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'DKIM checks with no signing configuration' -ForEach @(
    @{ CommandName = 'Test-MtCisDkim' }
    @{ CommandName = 'Test-MtCisaDkim' }
) {
    BeforeEach {
        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
        Mock -ModuleName Maester Resolve-MtDnsRecord {
            [PSCustomObject]@{ Name = $Name; Type = $Type; Status = 'NXDomain'; Answers = [object[]]@() }
        }
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
                    'Test-MtCisDkim'  = $true
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

        $parameters = if ($CommandName -eq 'Test-MtCisDkim' -and $DomainName -eq 'parked.example') { @{ ParkedDomains = 'parked.example' } } else { @{} }
        $result = & $CommandName @parameters
        if ($null -eq $expectedResult) {
            $result | Should -BeNullOrEmpty
        } else {
            $result | Should -Be $expectedResult
        }
        Should -Invoke Get-MailAuthenticationRecord -ModuleName Maester -Exactly 0
    }
}

Describe 'CIS DKIM with ParkedDomains' {
    BeforeEach {
        $script:acceptedDomains = @([PSCustomObject]@{ DomainName = 'parked.example'; InitialDomain = $false; IsCoexistenceDomain = $false })
        # Name -> status for the selector lookups; anything not listed is NXDomain.
        $script:selectorStatus = @{}
        $script:selectorRecords = @{}
        Mock -ModuleName Maester Add-MtTestResultDetail {
            $script:detail = [PSCustomObject]@{ Result = $Result; Investigate = [bool]$Investigate; SkippedBecause = $SkippedBecause }
        }
        Mock -ModuleName Maester Get-MtExo {
            if ($Request -eq 'AcceptedDomain') { return $script:acceptedDomains }
            return @()
        }
        Mock -ModuleName Maester Get-MailAuthenticationRecord { throw 'No Exchange DKIM lookup should be needed for a parked domain.' }
        Mock -ModuleName Maester Resolve-MtDnsRecord {
            $key = "$Type|$Name"
            $status = if ($script:selectorStatus.ContainsKey($key)) { $script:selectorStatus[$key] } elseif ($script:selectorRecords.ContainsKey($key)) { 'Success' } else { 'NXDomain' }
            $answers = if ($script:selectorRecords.ContainsKey($key)) { [object[]]@([PSCustomObject]@{ Value = $script:selectorRecords[$key] }) } else { [object[]]@() }
            [PSCustomObject]@{ Name = $Name; Type = $Type; Status = $status; Answers = $answers }
        }
    }

    It 'checks a domain against the sending-domain audit unless it is listed' {
        Test-MtCisDkim | Should -BeFalse
        $script:detail.Result | Should -Match '\| parked\.example \| Sending \|'
        Should -Invoke Resolve-MtDnsRecord -ModuleName Maester -Exactly 0
    }

    It 'uses the shared ParkedDomains setting when no test override is supplied' {
        Mock Get-MtSetting -ModuleName Maester { @('parked.example') }

        Test-MtCisDkim | Should -BeTrue
        $script:detail.Result | Should -Match '\| parked\.example \| Parked \|'
    }

    It 'passes a listed domain with no selector records' {
        Test-MtCisDkim -ParkedDomains 'PARKED.example.' | Should -BeTrue
        $script:detail.Result | Should -Match '\| parked\.example \| Parked \|'
        $script:detail.Result | Should -Match 'Well done'
        Should -Invoke Resolve-MtDnsRecord -ModuleName Maester -Exactly 4
    }

    It 'fails a listed domain that publishes a selector record' {
        $script:selectorRecords['CNAME|selector1._domainkey.parked.example'] = 'selector1-parked-example._domainkey.contoso.onmicrosoft.com'

        Test-MtCisDkim -ParkedDomains 'parked.example' | Should -BeFalse
        $script:detail.Result | Should -Match 'a selector1 or selector2 DKIM record is published'
    }

    It 'fails a listed domain with a selector record even when another lookup failed' {
        $script:selectorRecords['TXT|selector2._domainkey.parked.example'] = 'v=DKIM1; p=abc'
        $script:selectorStatus['CNAME|selector1._domainkey.parked.example'] = 'Error'

        Test-MtCisDkim -ParkedDomains 'parked.example' | Should -BeFalse
        $script:detail.Investigate | Should -BeFalse
    }

    It 'investigates a listed domain when a selector lookup fails' {
        $script:selectorStatus['CNAME|selector1._domainkey.parked.example'] = 'Error'

        Test-MtCisDkim -ParkedDomains 'parked.example' | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Result | Should -Match 'Compliance .* remains unconfirmed'
    }

    It 'skips with NotSupported when DNS lookups are not available' {
        foreach ($selector in 'selector1', 'selector2') {
            foreach ($type in 'CNAME', 'TXT') { $script:selectorStatus["$type|$selector._domainkey.parked.example"] = 'NotAvailable' }
        }

        Test-MtCisDkim -ParkedDomains 'parked.example' | Should -BeNullOrEmpty
        $script:detail.SkippedBecause | Should -Be 'NotSupported'
    }

    It 'reports a compliant parked domain alongside one that <OtherOutcome>' -ForEach @(
        @{ OtherOutcome = 'needs investigation'; Status = 'Error'; ExpectedResult = $true; ExpectedInvestigation = $true; ExpectedUnconfirmed = $true }
        @{ OtherOutcome = 'cannot be checked'; Status = 'NotAvailable'; ExpectedResult = $true; ExpectedInvestigation = $true; ExpectedUnconfirmed = $true }
        @{ OtherOutcome = 'passes'; Status = $null; ExpectedResult = $true; ExpectedInvestigation = $false; ExpectedUnconfirmed = $false }
    ) {
        $script:acceptedDomains += [PSCustomObject]@{ DomainName = 'other.example'; InitialDomain = $false; IsCoexistenceDomain = $false }
        if ($Status) {
            foreach ($selector in 'selector1', 'selector2') {
                foreach ($type in 'CNAME', 'TXT') { $script:selectorStatus["$type|$selector._domainkey.other.example"] = $Status }
            }
        }

        Test-MtCisDkim -ParkedDomains 'parked.example', 'other.example' | Should -Be $ExpectedResult
        $script:detail.Investigate | Should -Be $ExpectedInvestigation
        $script:detail.SkippedBecause | Should -BeNullOrEmpty
        $script:detail.Result | Should -Match '\| parked\.example .*Pass'
        if ($ExpectedUnconfirmed) {
            $script:detail.Result | Should -Match 'Compliance .* remains unconfirmed'
            $script:detail.Result | Should -Not -Match 'Well done'
        } else {
            $script:detail.Result | Should -Match 'Well done'
        }
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
