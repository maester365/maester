Describe 'CIS M365 SPF check' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisSpfRecordsPublished

        Mock Get-MtExo -ModuleName Maester {
            if ($Request -eq 'AcceptedDomain') { return $script:domains }
            return $script:dkimSigningConfigs
        }
        Mock ConvertFrom-MailAuthenticationRecordSpf -ModuleName Maester { $script:spfResults[$DomainName] }
        Mock Get-MtCisParkedDomainClassification -ModuleName Maester {
            $classification = $script:classifications[$DomainName]
            if ($ParkedDomains -contains $DomainName) {
                $classification.Classification = 'Parked'
            }
            return $classification
        }
        Mock Add-MtTestResultDetail -ModuleName Maester {
            $script:resultDetail = [pscustomobject]@{
                Result         = $Result
                Investigate    = [bool]$Investigate
                SkippedBecause = $SkippedBecause
            }
        }
    }

    BeforeEach {
        $script:domains = @([pscustomobject]@{ DomainName = 'example.com'; InitialDomain = $false; IsCoExistenceDomain = $false })
        $script:dkimSigningConfigs = @()
        $script:spfResults = @{}
        $script:classifications = @{}
        $script:resultDetail = $null
    }

    It 'requires a hard-fail SPF record for a parked domain' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 ~all' }
        $script:classifications['example.com'] = [pscustomobject]@{
            Classification = 'Parked'
            SpfDeniesAll   = $false
            Reason         = 'No sending or receiving signals were found.'
        }

        Test-MtCisSpfRecordsPublished | Should -BeFalse
        $script:resultDetail.Result | Should -Match 'parked/non-sending audit requires an SPF record'
    }

    It 'accepts a hard-fail SPF record for a parked domain' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 -all' }
        $script:classifications['example.com'] = [pscustomobject]@{
            Classification = 'Parked'
            SpfDeniesAll   = $true
            Reason         = 'No sending or receiving signals were found.'
        }

        Test-MtCisSpfRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeFalse
    }

    It 'keeps the soft-fail rule for sending domains' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 include:spf.example.net ~all' }
        $script:classifications['example.com'] = [pscustomobject]@{
            Classification = 'Sending'
            SpfDeniesAll   = $false
            Reason         = 'An SPF sending mechanism was found.'
        }

        Test-MtCisSpfRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeFalse
    }

    It 'requires the all qualifier to be the final sending-domain term' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 include:spf.example.net -all include:vendor.example' }
        $script:classifications['example.com'] = [pscustomobject]@{
            Classification = 'Sending'
            SpfDeniesAll   = $false
            Reason         = 'An SPF sending mechanism was found.'
        }

        Test-MtCisSpfRecordsPublished | Should -BeFalse
    }

    It 'investigates when a soft-fail record passes only the sending-domain rule' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 ~all' }
        $script:classifications['example.com'] = [pscustomobject]@{
            Classification = 'Unknown'
            SpfDeniesAll   = $false
            Reason         = 'Mail use is inconclusive.'
        }

        Test-MtCisSpfRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeTrue
    }

    It 'preserves <Outcome> when another SPF lookup is unavailable' -ForEach @(
        @{ Outcome = 'investigation'; Classification = 'Unknown'; Record = 'v=spf1 ~all'; ExpectedResult = $true; ExpectedInvestigation = $true; ExpectedSkip = $null }
        @{ Outcome = 'failure'; Classification = 'Sending'; Record = 'v=spf1 ?all'; ExpectedResult = $false; ExpectedInvestigation = $false; ExpectedSkip = $null }
        @{ Outcome = 'NotSupported without investigation'; Classification = 'Sending'; Record = 'v=spf1 ~all'; ExpectedResult = $null; ExpectedInvestigation = $false; ExpectedSkip = 'NotSupported' }
    ) {
        $script:domains += [pscustomobject]@{ DomainName = 'unavailable.example'; InitialDomain = $false; IsCoExistenceDomain = $false }
        $script:spfResults['example.com'] = [pscustomobject]@{ record = $Record }
        $script:spfResults['unavailable.example'] = 'DNS lookup unavailable'
        $script:classifications['example.com'] = [pscustomobject]@{
            Classification = $Classification
            SpfDeniesAll   = $false
            Reason         = 'Mail-use evidence for this test.'
        }
        $script:classifications['unavailable.example'] = [pscustomobject]@{
            Classification = 'Unknown'
            SpfDeniesAll   = $false
            Reason         = 'DNS lookup unavailable.'
        }

        $actual = Test-MtCisSpfRecordsPublished

        $actual | Should -Be $ExpectedResult
        $script:resultDetail.Investigate | Should -Be $ExpectedInvestigation
        $script:resultDetail.SkippedBecause | Should -Be $ExpectedSkip
        if ($null -eq $ExpectedSkip) {
            $script:resultDetail.Result | Should -Match '\| unavailable\.example .* \| Not checked \|'
            if ($ExpectedInvestigation) {
                $script:resultDetail.Result | Should -Match '\| example\.com \| Unknown .* \| Investigate \|'
            }
        }
    }

    It 'investigates an indirect all policy when parked status is unknown' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 redirect=_spf.example.net' }
        $script:spfResults['_spf.example.net'] = [pscustomobject]@{ record = 'v=spf1 -all' }
        $script:classifications['example.com'] = [pscustomobject]@{
            Classification = 'Unknown'
            SpfDeniesAll   = $false
            Reason         = 'The SPF redirect target is inconclusive.'
        }

        Test-MtCisSpfRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeTrue
    }

    It 'applies a parked override but still requires hard fail' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 ~all' }
        $script:classifications['example.com'] = [pscustomobject]@{
            Classification = 'Unknown'
            SpfDeniesAll   = $false
            Reason         = 'Mail use is inconclusive.'
        }

        Test-MtCisSpfRecordsPublished -ParkedDomains 'example.com' | Should -BeFalse
    }
}
