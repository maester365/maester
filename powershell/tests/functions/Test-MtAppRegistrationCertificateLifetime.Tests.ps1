Describe 'Test-MtAppRegistrationCertificateLifetime' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        function New-TestApp {
            param($DisplayName, $AppId, $Certificates)

            return [PSCustomObject]@{
                id             = [guid]::NewGuid().ToString()
                displayName    = $DisplayName
                appId          = $AppId
                keyCredentials = @($Certificates)
            }
        }

        function New-TestCertificate {
            param($DisplayName, $StartsDaysFromNow, $EndsDaysFromNow, $Usage = 'Verify', $Thumbprint = 'AAAA')

            $base = Get-Date

            return [PSCustomObject]@{
                keyId               = [guid]::NewGuid().ToString()
                customKeyIdentifier = $Thumbprint
                displayName         = $DisplayName
                usage               = $Usage
                # Derive both dates from a single timestamp so the validity period is exact.
                # Two separate Get-Date calls drift by microseconds and skew the day count.
                startDateTime       = $base.AddDays($StartsDaysFromNow)
                endDateTime         = $base.AddDays($EndsDaysFromNow)
            }
        }
    }

    BeforeEach {
        $script:Result = $null
        $script:SkippedBecause = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause)
            $script:Result = $Result
            $script:SkippedBecause = $SkippedBecause
        }
    }

    It 'passes when every certificate is within the maximum validity period' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Short lived app' -AppId '11111111-1111-1111-1111-111111111111' -Certificates @(
                New-TestCertificate -DisplayName 'CN=short' -StartsDaysFromNow -10 -EndsDaysFromNow 80
            )
        }

        Test-MtAppRegistrationCertificateLifetime | Should -BeTrue
        $script:Result | Should -BeLike '*Well done*'
    }

    It 'fails and lists the certificate when the validity period is excessive' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Backup Job' -AppId '22222222-2222-2222-2222-222222222222' -Certificates @(
                New-TestCertificate -DisplayName 'CN=backup' -StartsDaysFromNow -30 -EndsDaysFromNow 1065
            )
        }

        Test-MtAppRegistrationCertificateLifetime | Should -BeFalse
        $script:Result | Should -BeLike '*1 certificate(s) on 1 app registration(s)*'
        $script:Result | Should -BeLike '*CN=backup*'
        $script:Result | Should -BeLike '*1095 days*'
        $script:Result | Should -BeLike '*22222222-2222-2222-2222-222222222222*'
    }

    It 'ignores certificates that have already expired' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Retired app' -AppId '33333333-3333-3333-3333-333333333333' -Certificates @(
                New-TestCertificate -DisplayName 'CN=retired' -StartsDaysFromNow -800 -EndsDaysFromNow -10
            )
        }

        Test-MtAppRegistrationCertificateLifetime | Should -BeTrue
    }

    It 'counts a certificate listed for both Sign and Verify usage only once' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Dual usage app' -AppId '44444444-4444-4444-4444-444444444444' -Certificates @(
                New-TestCertificate -DisplayName 'CN=dual' -StartsDaysFromNow -30 -EndsDaysFromNow 1065 -Usage 'Verify' -Thumbprint 'BBBB'
                New-TestCertificate -DisplayName 'CN=dual' -StartsDaysFromNow -30 -EndsDaysFromNow 1065 -Usage 'Sign' -Thumbprint 'BBBB'
            )
        }

        Test-MtAppRegistrationCertificateLifetime | Should -BeFalse
        $script:Result | Should -BeLike '*1 certificate(s) on 1 app registration(s)*'
    }

    It 'honours a custom maximum validity period' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Two hundred days' -AppId '55555555-5555-5555-5555-555555555555' -Certificates @(
                New-TestCertificate -DisplayName 'CN=medium' -StartsDaysFromNow -10 -EndsDaysFromNow 190
            )
        }

        Test-MtAppRegistrationCertificateLifetime | Should -BeTrue
        Test-MtAppRegistrationCertificateLifetime -MaximumValidityDays 90 | Should -BeFalse
    }

    It 'reports a certificate that exceeds the maximum by less than a day' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            # 365 days and one second. Rounding the lifetime to whole days would hide this.
            $start = (Get-Date).AddDays(-1)
            New-TestApp -DisplayName 'Just over the limit' -AppId '66666666-6666-6666-6666-666666666666' -Certificates @(
                [PSCustomObject]@{
                    keyId               = [guid]::NewGuid().ToString()
                    customKeyIdentifier = 'CCCC'
                    displayName         = 'CN=just-over'
                    usage               = 'Verify'
                    startDateTime       = $start
                    endDateTime         = $start.AddDays(365).AddSeconds(1)
                }
            )
        }

        Test-MtAppRegistrationCertificateLifetime | Should -BeFalse
        $script:Result | Should -BeLike '*CN=just-over*'
    }

    It 'passes when no app registration has certificates' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtAppRegistrationCertificateLifetime | Should -BeTrue
        $script:Result | Should -BeLike '*Well done*'
    }

    It 'skips when Microsoft Graph is not connected' {
        Mock -ModuleName Maester Test-MtConnection { return $false }

        Test-MtAppRegistrationCertificateLifetime | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotConnectedGraph'
    }

    It 'skips when the Graph request fails' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'GET https://graph.microsoft.com/v1.0/applications HTTP/1.1 403 Forbidden' }

        Test-MtAppRegistrationCertificateLifetime | Should -BeNull
        $script:SkippedBecause | Should -Be 'Error'
    }
}
