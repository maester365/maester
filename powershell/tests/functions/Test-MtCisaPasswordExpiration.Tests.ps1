Describe 'Test-MtCisaPasswordExpiration' {
    BeforeAll {
        function New-TestDomain {
            param(
                [string]$Id,
                [bool]$IsVerified = $true,
                [string]$AuthenticationType = 'Managed',
                [object]$PasswordValidityPeriodInDays = $null,
                [object[]]$SupportedServices = @('Email'),
                [bool]$IsDefault = $false
            )

            return [PSCustomObject]@{
                id = $Id
                isVerified = $IsVerified
                authenticationType = $AuthenticationType
                PasswordValidityPeriodInDays = $PasswordValidityPeriodInDays
                supportedServices = $SupportedServices
                isDefault = $IsDefault
            }
        }
    }

    BeforeEach {
        $script:testResultMarkdown = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result)

            $script:testResultMarkdown = $Result
        }
    }

    It 'passes only when managed verified domains are explicitly set to never expire' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                (New-TestDomain -Id 'contoso.onmicrosoft.com' -PasswordValidityPeriodInDays ([int]::MaxValue) -IsDefault $true),
                (New-TestDomain -Id 'contoso.com' -PasswordValidityPeriodInDays ([int]::MaxValue))
            )
        }

        Test-MtCisaPasswordExpiration | Should -BeTrue
        $script:testResultMarkdown | Should -Match 'Well done'
    }

    It 'fails when PasswordValidityPeriodInDays is null because never expire is not explicitly configured' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                (New-TestDomain -Id 'contoso.onmicrosoft.com' -PasswordValidityPeriodInDays $null)
            )
        }

        Test-MtCisaPasswordExpiration | Should -BeFalse
        $script:testResultMarkdown | Should -Match 'not explicitly set to never expire'
    }

    It 'fails when PasswordValidityPeriodInDays is a finite value' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                (New-TestDomain -Id 'contoso.onmicrosoft.com' -PasswordValidityPeriodInDays 90)
            )
        }

        Test-MtCisaPasswordExpiration | Should -BeFalse
        $script:testResultMarkdown | Should -Match 'Password expiration is not explicitly set to never expire'
    }

    It 'skips SharePoint-only legacy domains and reports the reason' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                (New-TestDomain -Id 'contoso.onmicrosoft.com' -PasswordValidityPeriodInDays ([int]::MaxValue)),
                (New-TestDomain -Id 'contoso-public.sharepoint.com' -PasswordValidityPeriodInDays $null -SupportedServices @('SharePoint'))
            )
        }

        Test-MtCisaPasswordExpiration | Should -BeTrue
        $script:testResultMarkdown | Should -Match 'Legacy SharePoint-only domain'
    }

    It 'does not skip domains that include SharePoint alongside other supported services' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                (New-TestDomain -Id 'contoso.onmicrosoft.com' -PasswordValidityPeriodInDays ([int]::MaxValue)),
                (New-TestDomain -Id 'contoso.com' -PasswordValidityPeriodInDays $null -SupportedServices @('Email', 'SharePoint'))
            )
        }

        Test-MtCisaPasswordExpiration | Should -BeFalse
        $script:testResultMarkdown | Should -Match 'Password expiration is not explicitly set to never expire'
    }
}
