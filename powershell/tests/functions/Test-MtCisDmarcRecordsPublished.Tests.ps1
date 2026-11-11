Describe 'CIS M365 DMARC check' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisDmarcRecordsPublished

        $script:parkedDmarcRecord = [pscustomobject]@{
            valid           = $true
            policy          = 'reject'
            policySubdomain = $null
            percentage      = 100
            reportAggregate = @()
            reportForensic  = @()
        }
        $script:quarantineDmarcRecord = [pscustomobject]@{
            valid           = $true
            policy          = 'quarantine'
            policySubdomain = $null
            percentage      = 100
            reportAggregate = @()
            reportForensic  = @()
        }
        $script:fullyCompliantDmarcRecord = [pscustomobject]@{
            valid           = $true
            policy          = 'reject'
            policySubdomain = $null
            percentage      = 100
            reportAggregate = @([pscustomobject]@{ mailAddress = 'reports@example.com' })
            reportForensic  = @([pscustomobject]@{ mailAddress = 'forensic@example.com' })
        }

        $script:domains = @()
        $script:registrableDomains = @{}
        $script:dmarcResults = @{}
        $script:dkimSigningConfigs = @()

        Mock Get-MtExo -ModuleName Maester {
            if ($Request -eq 'AcceptedDomain') { return $script:domains }
            return $script:dkimSigningConfigs
        }
        Mock Get-MtRegistrableDomain -ModuleName Maester { $script:registrableDomains[$DomainName] }
        Mock ConvertFrom-MailAuthenticationRecordDmarc -ModuleName Maester { $script:dmarcResults[$DomainName] }
        Mock Add-MtTestResultDetail -ModuleName Maester {
            $script:resultDetail = [pscustomobject]@{ Result = $Result; Investigate = [bool]$Investigate; SkippedBecause = $SkippedBecause }
        }
    }

    BeforeEach {
        $script:domains = @()
        $script:registrableDomains = @{}
        $script:dmarcResults = @{}
        $script:dkimSigningConfigs = @()
        $script:resultDetail = $null
    }

    It 'fails a known noncompliant domain before skipping an unavailable lookup' {
        $script:domains = @(
            [pscustomobject]@{ DomainName = 'bad.example'; IsCoExistenceDomain = $false }
            [pscustomobject]@{ DomainName = 'unavailable.example'; IsCoExistenceDomain = $false }
        )
        $script:registrableDomains = @{
            'bad.example'         = 'bad.example'
            'unavailable.example' = 'unavailable.example'
        }
        $script:dmarcResults = @{
            'bad.example'         = 'Failure to obtain record'
            'unavailable.example' = 'DNS lookup unavailable'
        }

        Test-MtCisDmarcRecordsPublished | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -match '1 domain\(s\) do not have a compliant DMARC policy'
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 0 -Exactly -ParameterFilter {
            $SkippedBecause -eq 'NotSupported'
        }
    }

    It 'returns <Outcome> when another DMARC lookup is unavailable' -ForEach @(
        @{ Outcome = 'a failure'; Parked = @(); ExpectedResult = $false; ExpectedSkip = $null }
        @{ Outcome = 'NotSupported'; Parked = @('example.com'); ExpectedResult = $null; ExpectedSkip = 'NotSupported' }
    ) {
        $script:domains = @(
            [pscustomobject]@{ DomainName = 'example.com'; IsCoExistenceDomain = $false }
            [pscustomobject]@{ DomainName = 'unavailable.example'; IsCoExistenceDomain = $false }
        )
        $script:registrableDomains = @{
            'example.com'         = 'example.com'
            'unavailable.example' = 'unavailable.example'
        }
        $script:dmarcResults = @{
            'example.com'         = $script:parkedDmarcRecord
            'unavailable.example' = 'DNS lookup unavailable'
        }

        Test-MtCisDmarcRecordsPublished -ParkedDomains $Parked | Should -Be $ExpectedResult
        $script:resultDetail.SkippedBecause | Should -Be $ExpectedSkip
        if ($null -eq $ExpectedSkip) {
            $script:resultDetail.Result | Should -Match '\| unavailable\.example .* \| Not checked \|'
        }
    }

    It 'looks up the organizational domain after an invalid subdomain record and reports an invalid effective record' {
        $script:domains = @([pscustomobject]@{ DomainName = 'mail.example.com'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'mail.example.com' = 'example.com' }
        $script:dmarcResults = @{
            'mail.example.com' = 'Invalid DMARC record'
            'example.com'      = 'Failure to obtain record'
        }

        Test-MtCisDmarcRecordsPublished | Should -BeFalse
        Should -Invoke ConvertFrom-MailAuthenticationRecordDmarc -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $DomainName -eq 'example.com'
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -match 'Invalid DMARC record' -and $Result -match 'mail.example.com'
        }
    }

    It 'requires p=reject but not reporting tags for parked domains' {
        $script:domains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'parked.example' = 'parked.example' }
        $script:dmarcResults = @{ 'parked.example' = $script:parkedDmarcRecord }

        Test-MtCisDmarcRecordsPublished -ParkedDomains 'parked.example' | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeFalse
        $script:resultDetail.Result | Should -Match '\| parked\.example \| Parked \|'
    }

    It 'uses the shared ParkedDomains setting when no test override is supplied' {
        $script:domains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'parked.example' = 'parked.example' }
        $script:dmarcResults = @{ 'parked.example' = $script:parkedDmarcRecord }
        Mock Get-MtSetting -ModuleName Maester { @('parked.example') }

        Test-MtCisDmarcRecordsPublished | Should -BeTrue
        $script:resultDetail.Result | Should -Match '\| parked\.example \| Parked \|'
    }

    It 'fails a parked domain whose DMARC policy is quarantine' {
        $script:domains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'parked.example' = 'parked.example' }
        $script:dmarcResults = @{ 'parked.example' = $script:quarantineDmarcRecord }

        Test-MtCisDmarcRecordsPublished -ParkedDomains 'parked.example' | Should -BeFalse
        $script:resultDetail.Result | Should -Match 'Parked-domain policy is reject'
    }

    It 'applies the sending-domain audit to a domain that is not listed' {
        $script:domains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'parked.example' = 'parked.example' }
        $script:dmarcResults = @{ 'parked.example' = $script:parkedDmarcRecord }

        Test-MtCisDmarcRecordsPublished | Should -BeFalse
        $script:resultDetail.Result | Should -Match '\| parked\.example \| Sending \|'
        $script:resultDetail.Result | Should -Match 'Aggregate reports \(rua\)'
    }

    It 'accepts a fully compliant DMARC record for a sending domain' {
        $script:domains = @([pscustomobject]@{ DomainName = 'sending.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'sending.example' = 'sending.example' }
        $script:dmarcResults = @{ 'sending.example' = $script:fullyCompliantDmarcRecord }

        Test-MtCisDmarcRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeFalse
        $script:resultDetail.Result | Should -Match 'Well done\. All accepted domains meet'
    }
}
