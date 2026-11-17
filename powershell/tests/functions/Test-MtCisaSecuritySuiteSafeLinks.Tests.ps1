BeforeAll {
    $testRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.7.1.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.7.2.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.7.3.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.8.1.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.8.2.ps1')
    . (Join-Path $testRoot 'powershell\internal\checks\cisa\exchange\Get-MtCisaEffectiveSafeLinksPolicy.ps1')
}
Describe 'CISA Security Suite Safe Links checks' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'requires the effective Safe Links policy to protect all channels and internal senders' {
        $script:exoResponses = @{
            SafeLinksPolicy = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; RecommendedPolicyType = 'Strict'
                    EnableSafeLinksForEmail = $true; EnableSafeLinksForTeams = $true
                    EnableSafeLinksForOffice = $true; EnableForInternalSenders = $true
                }
            )
            ATPProtectionPolicyRule = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; State = 'Enabled'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
            SafeLinksRule = @()
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSafeLink | Should -BeTrue

        $script:exoResponses.SafeLinksPolicy[0].EnableForInternalSenders = $false
        Test-MtCisaSafeLink | Should -BeFalse
    }

    It 'selects the highest-priority enabled Safe Links rule that covers all recipients' {
        $script:exoResponses = @{
            SafeLinksPolicy = @(
                [pscustomobject]@{
                    Identity = 'All recipients'; Name = 'All recipients'
                    EnableSafeLinksForEmail = $true; EnableSafeLinksForTeams = $true
                    EnableSafeLinksForOffice = $true; EnableForInternalSenders = $true
                }
            )
            ATPProtectionPolicyRule = @()
            SafeLinksRule = @(
                [pscustomobject]@{
                    State = 'Enabled'; Priority = 1; SafeLinksPolicy = 'Scoped'
                    SentTo = @('user@contoso.com'); SentToMemberOf = @(); RecipientDomainIs = @()
                },
                [pscustomobject]@{
                    State = 'Enabled'; Priority = 2; SafeLinksPolicy = 'All recipients'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSafeLink | Should -BeTrue
    }

    It 'checks URL scanning and deliver-after-scan on the effective Safe Links policy' {
        $script:exoResponses = @{
            SafeLinksPolicy = @(
                [pscustomobject]@{
                    Identity = 'Scoped'; ScanUrls = $true; DeliverMessageAfterScan = $true
                },
                [pscustomobject]@{
                    Identity = 'All recipients'; ScanUrls = $true; DeliverMessageAfterScan = $true
                }
            )
            ATPProtectionPolicyRule = @()
            SafeLinksRule = @(
                [pscustomobject]@{
                    State = 'Enabled'; Priority = 1; SafeLinksPolicy = 'Scoped'
                    SentTo = @('user@contoso.com'); SentToMemberOf = @(); RecipientDomainIs = @()
                },
                [pscustomobject]@{
                    State = 'Enabled'; Priority = 2; SafeLinksPolicy = 'All recipients'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSafeLinkDownloadScan | Should -BeTrue

        $script:exoResponses.SafeLinksPolicy[1].DeliverMessageAfterScan = $false
        Test-MtCisaSafeLinkDownloadScan | Should -BeFalse
    }

    It 'checks click tracking only on the effective Safe Links policy' {
        $script:exoResponses = @{
            SafeLinksPolicy = @(
                [pscustomobject]@{ Identity = 'All recipients'; TrackClicks = $false },
                [pscustomobject]@{ Identity = 'Unrelated'; TrackClicks = $true }
            )
            ATPProtectionPolicyRule = @()
            SafeLinksRule = @(
                [pscustomobject]@{
                    State = 'Enabled'; Priority = 1; SafeLinksPolicy = 'All recipients'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSafeLinkClickTracking | Should -BeFalse

        $script:exoResponses.SafeLinksPolicy[0].TrackClicks = $true
        Test-MtCisaSafeLinkClickTracking | Should -BeTrue
    }

    It 'accepts an all-recipient preset policy for scanning and click-tracking requirements' {
        $script:exoResponses = @{
            SafeLinksPolicy = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; RecommendedPolicyType = 'Strict'
                    ScanUrls = $false; DeliverMessageAfterScan = $false; TrackClicks = $false
                }
            )
            ATPProtectionPolicyRule = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; State = 'Enabled'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
            SafeLinksRule = @()
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSafeLinkDownloadScan | Should -BeTrue
        Test-MtCisaSafeLinkClickTracking | Should -BeTrue
    }

    It 'uses the Defender preset rule scope rather than the EOP preset rule scope' {
        $script:exoResponses = @{
            SafeLinksPolicy = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; RecommendedPolicyType = 'Strict'
                    ScanUrls = $true; DeliverMessageAfterScan = $true; TrackClicks = $true
                },
                [pscustomobject]@{
                    Identity = 'All recipients'; Name = 'All recipients'
                    ScanUrls = $false; DeliverMessageAfterScan = $false; TrackClicks = $false
                }
            )
            ATPProtectionPolicyRule = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; State = 'Enabled'
                    SentTo = @('user@contoso.com'); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
            EOPProtectionPolicyRule = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; State = 'Enabled'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
            SafeLinksRule = @(
                [pscustomobject]@{
                    State = 'Enabled'; Priority = 1; SafeLinksPolicy = 'All recipients'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        (Get-MtCisaEffectiveSafeLinksPolicy).Policy.Identity | Should -Be 'All recipients'
        Test-MtCisaSafeLinkDownloadScan | Should -BeFalse
        Test-MtCisaSafeLinkClickTracking | Should -BeFalse
    }

    It 'fails Safe List compliance if any returned connection filter enables it' {
        $script:exoResponses = @{
            HostedConnectionFilterPolicy = @(
                [pscustomobject]@{ Name = 'Default'; EnableSafeList = $false },
                [pscustomobject]@{ Name = 'Additional'; EnableSafeList = $false }
            )
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaAntiSpamSafeList | Should -BeTrue

        $script:exoResponses.HostedConnectionFilterPolicy[1].EnableSafeList = $true
        Test-MtCisaAntiSpamSafeList | Should -BeFalse
    }

    It 'does not pass Safe List compliance when no connection filter policy is returned' {
        $script:exoResponses = @{ HostedConnectionFilterPolicy = @() }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaAntiSpamSafeList | Should -BeFalse
    }

    It 'does not pass IP allow-list compliance when no connection filter policy is returned' {
        $script:exoResponses = @{ HostedConnectionFilterPolicy = @() }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaAntiSpamAllowList | Should -BeFalse
    }
}
