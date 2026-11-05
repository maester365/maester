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
        $script:classifications = @{}
        $script:dkimSigningConfigs = @()

        Mock Get-MtExo -ModuleName Maester {
            if ($Request -eq 'AcceptedDomain') { return $script:domains }
            return $script:dkimSigningConfigs
        }
        Mock Get-MtRegistrableDomain -ModuleName Maester { $script:registrableDomains[$DomainName] }
        Mock ConvertFrom-MailAuthenticationRecordDmarc -ModuleName Maester { $script:dmarcResults[$DomainName] }
        Mock Get-MtCisParkedDomainClassification -ModuleName Maester {
            $classification = if ($script:classifications.ContainsKey($DomainName)) {
                $script:classifications[$DomainName]
            } else {
                [pscustomobject]@{ Classification = 'Sending'; Reason = 'Sending-domain test default.' }
            }
            if ($ParkedDomains -contains $DomainName) {
                $classification.Classification = 'Parked'
            }
            return $classification
        }
        Mock Add-MtTestResultDetail -ModuleName Maester {
            $script:resultDetail = [pscustomobject]@{ Result = $Result; Investigate = [bool]$Investigate; SkippedBecause = $SkippedBecause }
        }
    }

    BeforeEach {
        $script:domains = @()
        $script:registrableDomains = @{}
        $script:dmarcResults = @{}
        $script:classifications = @{}
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
        $script:classifications = @{ 'parked.example' = [pscustomobject]@{ Classification = 'Parked'; Reason = 'No mail-use signals were found.' } }

        Test-MtCisDmarcRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeFalse
    }

    It 'fails a parked domain whose DMARC policy is quarantine' {
        $script:domains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'parked.example' = 'parked.example' }
        $script:dmarcResults = @{ 'parked.example' = $script:quarantineDmarcRecord }
        $script:classifications = @{ 'parked.example' = [pscustomobject]@{ Classification = 'Parked'; Reason = 'No mail-use signals were found.' } }

        Test-MtCisDmarcRecordsPublished | Should -BeFalse
    }

    It 'investigates an unknown domain when only the parked-domain policy passes' {
        $script:domains = @([pscustomobject]@{ DomainName = 'unknown.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'unknown.example' = 'unknown.example' }
        $script:dmarcResults = @{ 'unknown.example' = $script:parkedDmarcRecord }
        $script:classifications = @{ 'unknown.example' = [pscustomobject]@{ Classification = 'Unknown'; Reason = 'DNS evidence is incomplete.' } }

        Test-MtCisDmarcRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeTrue
        $script:resultDetail.Result | Should -Match '\| unknown\.example \| Unknown .* \| Investigate \|'
        $script:resultDetail.Result | Should -Not -Match '\| unknown\.example .*✅ Pass \|'
    }

    It 'applies an explicit parked override and requires reject policy' {
        $script:domains = @([pscustomobject]@{ DomainName = 'unknown.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'unknown.example' = 'unknown.example' }
        $script:dmarcResults = @{ 'unknown.example' = $script:quarantineDmarcRecord }
        $script:classifications = @{ 'unknown.example' = [pscustomobject]@{ Classification = 'Unknown'; Reason = 'DNS evidence is incomplete.' } }

        Test-MtCisDmarcRecordsPublished -ParkedDomains 'unknown.example' | Should -BeFalse
    }

    It 'accepts a fully compliant DMARC record when both procedures pass' {
        $script:domains = @([pscustomobject]@{ DomainName = 'unknown.example'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'unknown.example' = 'unknown.example' }
        $script:dmarcResults = @{ 'unknown.example' = $script:fullyCompliantDmarcRecord }
        $script:classifications = @{ 'unknown.example' = [pscustomobject]@{ Classification = 'Unknown'; Reason = 'DNS evidence is incomplete.' } }

        Test-MtCisDmarcRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeFalse
    }
}
