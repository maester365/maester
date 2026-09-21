Describe 'Test-MtAppRegistrationCredentialExpiry' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        function New-TestApp {
            param($DisplayName, $AppId, $Certificates = @(), $Secrets = @())

            return [PSCustomObject]@{
                id                  = [guid]::NewGuid().ToString()
                displayName         = $DisplayName
                appId               = $AppId
                keyCredentials      = @($Certificates)
                passwordCredentials = @($Secrets)
            }
        }

        function New-TestCertificate {
            param($DisplayName, $EndsDaysFromNow, $Usage = 'Verify', $Thumbprint = 'AAAA')

            # Derive both dates from a single timestamp so the remaining lifetime is exact.
            $base = Get-Date

            return [PSCustomObject]@{
                keyId               = [guid]::NewGuid().ToString()
                customKeyIdentifier = $Thumbprint
                displayName         = $DisplayName
                usage               = $Usage
                startDateTime       = $base.AddDays(-365)
                endDateTime         = $base.AddDays($EndsDaysFromNow)
            }
        }

        function New-TestSecret {
            param($DisplayName, $EndsDaysFromNow)

            $base = Get-Date

            return [PSCustomObject]@{
                keyId         = [guid]::NewGuid().ToString()
                displayName   = $DisplayName
                startDateTime = $base.AddDays(-365)
                endDateTime   = $base.AddDays($EndsDaysFromNow)
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

    It 'passes when every credential is valid well beyond the threshold' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Healthy app' -AppId '11111111-1111-1111-1111-111111111111' `
                -Certificates @(New-TestCertificate -DisplayName 'CN=healthy' -EndsDaysFromNow 200) `
                -Secrets @(New-TestSecret -DisplayName 'rotated secret' -EndsDaysFromNow 120)
        }

        Test-MtAppRegistrationCredentialExpiry | Should -BeTrue
        $script:Result | Should -BeLike '*Well done*'
    }

    It 'reports a certificate that expires within the threshold' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Backup Job' -AppId '22222222-2222-2222-2222-222222222222' `
                -Certificates @(New-TestCertificate -DisplayName 'CN=backup' -EndsDaysFromNow 10)
        }

        Test-MtAppRegistrationCredentialExpiry | Should -BeFalse
        $script:Result | Should -BeLike '*1 credential(s) on 1 app registration(s)*'
        $script:Result | Should -BeLike '*CN=backup*'
        $script:Result | Should -BeLike '*Certificate*'
        $script:Result | Should -BeLike '*Expires in 10 day(s)*'
    }

    It 'reports a secret that expires within the threshold' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Reporting Connector' -AppId '33333333-3333-3333-3333-333333333333' `
                -Secrets @(New-TestSecret -DisplayName 'reporting secret' -EndsDaysFromNow 3)
        }

        Test-MtAppRegistrationCredentialExpiry | Should -BeFalse
        $script:Result | Should -BeLike '*reporting secret*'
        $script:Result | Should -BeLike '*Secret*'
        $script:Result | Should -BeLike '*Expires in 3 day(s)*'
    }

    It 'reports a credential that has already expired' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Retired app' -AppId '44444444-4444-4444-4444-444444444444' `
                -Certificates @(New-TestCertificate -DisplayName 'CN=retired' -EndsDaysFromNow -40)
        }

        Test-MtAppRegistrationCredentialExpiry | Should -BeFalse
        $script:Result | Should -BeLike '*CN=retired*'
        $script:Result | Should -BeLike '*Expired 40 day(s) ago*'
    }

    It 'reports certificates and secrets of the same app in one table' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Mixed app' -AppId '55555555-5555-5555-5555-555555555555' `
                -Certificates @(New-TestCertificate -DisplayName 'CN=mixed' -EndsDaysFromNow 5) `
                -Secrets @(New-TestSecret -DisplayName 'mixed secret' -EndsDaysFromNow -2)
        }

        Test-MtAppRegistrationCredentialExpiry | Should -BeFalse
        $script:Result | Should -BeLike '*2 credential(s) on 1 app registration(s)*'
        $script:Result | Should -BeLike '*CN=mixed*'
        $script:Result | Should -BeLike '*mixed secret*'
    }

    It 'counts a certificate listed for both Sign and Verify usage only once' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Dual usage app' -AppId '66666666-6666-6666-6666-666666666666' -Certificates @(
                New-TestCertificate -DisplayName 'CN=dual' -EndsDaysFromNow 7 -Usage 'Verify' -Thumbprint 'BBBB'
                New-TestCertificate -DisplayName 'CN=dual' -EndsDaysFromNow 7 -Usage 'Sign' -Thumbprint 'BBBB'
            )
        }

        Test-MtAppRegistrationCredentialExpiry | Should -BeFalse
        $script:Result | Should -BeLike '*1 credential(s) on 1 app registration(s)*'
    }

    It 'honours a custom threshold' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            New-TestApp -DisplayName 'Twenty days left' -AppId '77777777-7777-7777-7777-777777777777' `
                -Certificates @(New-TestCertificate -DisplayName 'CN=twenty' -EndsDaysFromNow 20)
        }

        Test-MtAppRegistrationCredentialExpiry | Should -BeFalse
        Test-MtAppRegistrationCredentialExpiry -ExpiringWithinDays 7 | Should -BeTrue
    }

    It 'passes when no app registration has credentials' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtAppRegistrationCredentialExpiry | Should -BeTrue
        $script:Result | Should -BeLike '*Well done*'
    }

    It 'skips when Microsoft Graph is not connected' {
        Mock -ModuleName Maester Test-MtConnection { return $false }

        Test-MtAppRegistrationCredentialExpiry | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotConnectedGraph'
    }

    It 'skips when the Graph request fails' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'GET https://graph.microsoft.com/v1.0/applications HTTP/1.1 403 Forbidden' }

        Test-MtAppRegistrationCredentialExpiry | Should -BeNull
        $script:SkippedBecause | Should -Be 'Error'
    }
}
