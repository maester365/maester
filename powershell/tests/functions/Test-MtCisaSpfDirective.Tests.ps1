BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    # Check functions that became native tests are not exported.
    Use-MtModuleFunction -Name Test-MtCisaSpfDirective

    function New-TestSpfRecord {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
        param(
            [string]$DomainName,
            # The SPF record, or the text the lookup returns when it finds none.
            [string]$Record
        )

        $spfRecord = $Record
        $spfLookups = @()
        if ($Record -like 'v=spf1*') {
            $terms = foreach ($term in ($Record -split '\s+' | Select-Object -Skip 1)) {
                $isAll = $term -match '^(?<qualifier>[-~?+]?)all$'
                [pscustomobject]@{
                    directive       = $term
                    qualifier       = if ($isAll) { $Matches.qualifier } else { '' }
                    mechanism       = if ($isAll) { 'all' } elseif ($term -like 'include:*') { 'include' } else { '' }
                    mechanismTarget = if ($term -like 'include:*') { $term.Substring(8) } else { '' }
                    modifier        = if ($term -like 'redirect=*') { 'redirect' } else { '' }
                }
            }
            $spfRecord = [pscustomobject]@{ record = $Record; terms = @($terms) }
            $spfLookups = @($terms | Where-Object { $_.mechanism -eq 'include' } | ForEach-Object {
                    [pscustomobject]@{ SPFSourceDomain = $_.mechanismTarget; Include = $true }
                })
        }

        return [pscustomobject]@{
            domain     = $DomainName
            spfRecord  = $spfRecord
            spfLookups = $spfLookups
        }
    }
}

Describe 'CISA.MS.EXO.2.2 with ParkedDomains' {
    BeforeEach {
        $script:acceptedDomains = @()
        $script:spfRecords = @{}
        Mock -ModuleName Maester Get-MtExo { return $script:acceptedDomains }
        Mock -ModuleName Maester Get-MailAuthenticationRecord {
            return New-TestSpfRecord -DomainName $DomainName -Record $script:spfRecords[$DomainName]
        }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'checks a domain that cannot send as a sending domain when it is not listed' {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false; SendingFromDomainDisabled = $true })
        $script:spfRecords['parked.example'] = 'v=spf1 include:spf.example.net -all'

        Test-MtCisaSpfDirective | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match '\| parked\.example \| ❌ Fail \| No Exchange Online directive \|' }
    }

    It 'accepts <Record> for a listed parked domain' -ForEach @(
        @{ Record = 'v=spf1 -all' }
        @{ Record = 'v=spf1 ~all' }
        @{ Record = 'v=spf1 include:spf.example.net -all' }
    ) {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false })
        $script:spfRecords['parked.example'] = $Record

        Test-MtCisaSpfDirective -ParkedDomains 'PARKED.example.' | Should -BeTrue

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match '\| parked\.example \| ✅ Pass \| Parked domain: fails all senders \|' }
    }

    It 'fails a listed parked domain that publishes <Record>' -ForEach @(
        @{ Record = 'v=spf1 ?all'; Reason = 'policy does not end in -all or ~all' }
        @{ Record = 'v=spf1 +all'; Reason = 'policy does not end in -all or ~all' }
        @{ Record = 'v=spf1 include:spf.protection.outlook.com'; Reason = 'policy does not end in -all or ~all' }
        @{ Record = 'Failure to obtain record'; Reason = 'Failure to obtain record' }
    ) {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false })
        $script:spfRecords['parked.example'] = $Record

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match ([regex]::Escape("| parked.example | ❌ Fail | Parked domain: $Reason |")) }
    }

    It 'still asks a sending domain for the Exchange Online directive' {
        $script:acceptedDomains = @(
            [pscustomobject]@{ DomainName = 'contoso.com'; IsCoexistenceDomain = $false }
            [pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false }
        )
        $script:spfRecords['contoso.com'] = 'v=spf1 -all'
        $script:spfRecords['parked.example'] = 'v=spf1 -all'

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match '\| contoso\.com \| ❌ Fail \|' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match '\| parked\.example \| ✅ Pass \|' }
    }

    It 'passes when the sending domain names Exchange Online and the parked domain fails all senders' {
        $script:acceptedDomains = @(
            [pscustomobject]@{ DomainName = 'contoso.com'; IsCoexistenceDomain = $false }
            [pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false }
        )
        $script:spfRecords['contoso.com'] = 'v=spf1 include:spf.protection.outlook.com -all'
        $script:spfRecords['parked.example'] = 'v=spf1 -all'

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeTrue
    }

    It 'is not supported when the only domain is parked and DNS is not available' {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false })
        $script:spfRecords['parked.example'] = 'Unsupported platform, Resolve-DnsName not available'

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'NotSupported' }
    }
}
