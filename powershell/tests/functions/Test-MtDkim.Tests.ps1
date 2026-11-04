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
            Mock -ModuleName Maester Get-MtCisParkedDomainClassification {
                $classification = if ($DomainName -eq 'parked.example') { 'Parked' } else { 'Sending' }
                [PSCustomObject]@{
                    DomainName     = $DomainName
                    Classification = $classification
                    IsParked       = $classification -eq 'Parked'
                    SpfRecord      = $null
                    SpfDeniesAll   = $false
                    DkimEvidence   = $false
                    DkimSelectorRecordEvidence = $false
                    DkimSelectorLookupsComplete = $true
                    Reason         = 'Mock domain classification'
                }
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

        $result = & $CommandName
        if ($null -eq $expectedResult) {
            $result | Should -BeNullOrEmpty
        } else {
            $result | Should -Be $expectedResult
        }
        Should -Invoke Get-MailAuthenticationRecord -ModuleName Maester -Exactly 0
    }
}

Describe 'CIS DKIM domain classification outcomes' {
    BeforeEach {
        Mock -ModuleName Maester Add-MtTestResultDetail {
            $script:detail = [PSCustomObject]@{ Result = $Result; Investigate = [bool]$Investigate; SkippedBecause = $SkippedBecause }
        }
        Mock -ModuleName Maester Get-MtExo {
            if ($Request -eq 'AcceptedDomain') {
                return @([PSCustomObject]@{ DomainName = 'unknown.example'; InitialDomain = $false; IsCoexistenceDomain = $false })
            }
            return @()
        }
        Mock -ModuleName Maester Get-MailAuthenticationRecord { throw 'No DKIM lookup should be needed for this classification.' }
    }

    It 'investigates domains whose sending use cannot be established' {
        Mock -ModuleName Maester Get-MtCisParkedDomainClassification {
            [PSCustomObject]@{ Classification = 'Unknown'; IsParked = $false; Reason = 'DNS evidence is incomplete.' }
        }

        Test-MtCisDkim | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
    }

    It 'fails a parked override when DKIM evidence remains' {
        Mock -ModuleName Maester Get-MtCisParkedDomainClassification {
            $classification = if ($ParkedDomains -contains $DomainName) { 'Parked' } else { 'Sending' }
            [PSCustomObject]@{ Classification = $classification; DkimEvidence = $true; DkimSelectorRecordEvidence = $true; DkimSelectorLookupsComplete = $true; Reason = 'Explicit parked override.' }
        }

        Test-MtCisDkim -ParkedDomains 'unknown.example' | Should -BeFalse
    }

    It 'passes a parked override with a signing configuration but no published selector records' {
        Mock -ModuleName Maester Get-MtCisParkedDomainClassification {
            [PSCustomObject]@{
                Classification               = 'Parked'
                DkimEvidence                 = $true
                DkimSelectorRecordEvidence   = $false
                DkimSelectorLookupsComplete  = $true
                Reason                       = 'An Exchange signing configuration exists, but no selector records are published.'
            }
        }

        Test-MtCisDkim -ParkedDomains 'unknown.example' | Should -BeTrue
    }

    It 'investigates a parked override when selector DNS lookups are incomplete' {
        Mock -ModuleName Maester Get-MtCisParkedDomainClassification {
            [PSCustomObject]@{
                Classification               = 'Parked'
                DkimSelectorRecordEvidence   = $false
                DkimSelectorLookupsComplete  = $false
                Reason                       = 'A selector DNS lookup failed.'
            }
        }

        Test-MtCisDkim -ParkedDomains 'unknown.example' | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
    }

    It 'fails a parked override when a selector record exists and another lookup is incomplete' {
        Mock -ModuleName Maester Get-MtCisParkedDomainClassification {
            [PSCustomObject]@{
                Classification               = 'Parked'
                DkimSelectorRecordEvidence   = $true
                DkimSelectorLookupsComplete  = $false
                Reason                       = 'A selector record exists and another lookup failed.'
            }
        }

        Test-MtCisDkim -ParkedDomains 'unknown.example' | Should -BeFalse
        $script:detail.Investigate | Should -BeFalse
        $script:detail.Result | Should -Match 'published standard DKIM selector record that must be removed'
    }

    It 'marks a non-sending receive domain out of scope for DKIM' {
        Mock -ModuleName Maester Get-MtCisParkedDomainClassification {
            [PSCustomObject]@{ Classification = 'NotSending'; IsParked = $false; Reason = 'The domain has receive-only DNS records.' }
        }

        Test-MtCisDkim | Should -BeNullOrEmpty
        $script:detail.SkippedBecause | Should -Be 'NotApplicable'
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
