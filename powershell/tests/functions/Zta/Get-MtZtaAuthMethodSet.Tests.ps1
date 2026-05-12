# Unit tests for Get-MtZtaAuthMethodSet.
# This cmdlet is the single source of truth for "which Graph
# authenticationMethod enum values are phish-resistant vs phishable" across
# MT.Zta.1140 / 1141 / 1142 / 1143. Drift in this set silently miscategorises
# every user, so the buckets must be locked.

Describe 'Get-MtZtaAuthMethodSet' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
    }

    Context 'Default invocation' {
        It 'returns a hashtable / object with PhishResistant + Phishable buckets' {
            $set = Get-MtZtaAuthMethodSet
            $set | Should -Not -BeNullOrEmpty
            $set.PhishResistant | Should -Not -BeNullOrEmpty
            $set.Phishable      | Should -Not -BeNullOrEmpty
        }

        It 'PhishResistant bucket contains the canonical Graph authenticationMethodModes for phish-resistant MFA' {
            $set = Get-MtZtaAuthMethodSet
            # Per Graph: fido2 / windowsHelloForBusiness / x509CertificateMultiFactor
            # are the only authentication-method modes that compose to phish-resistant MFA.
            # Device-bound passkeys appear in user-registration data; include them too.
            $set.PhishResistant | Should -Contain 'fido2'
            $set.PhishResistant | Should -Contain 'windowsHelloForBusiness'
        }

        It 'Phishable bucket contains the relayable / phone-bound enum values' {
            $set = Get-MtZtaAuthMethodSet
            # ZTA's UserRegistrationDetails.methodsRegistered enum emits phone-bound
            # methods as `mobilePhone` / `alternateMobilePhone` / `officePhone`
            # rather than the Graph CA authStrength enum value `sms`. The
            # phishable set tracks the URD vocabulary (that's the column
            # MT.Zta.1140-1143 read), not the CA-policy vocabulary.
            $set.Phishable | Should -Contain 'mobilePhone'
            $set.Phishable | Should -Contain 'voice'
            $set.Phishable | Should -Contain 'email'
        }

        It 'PhishResistant and Phishable are disjoint' {
            $set = Get-MtZtaAuthMethodSet
            $overlap = @($set.PhishResistant | Where-Object { $_ -in $set.Phishable })
            $overlap | Should -BeNullOrEmpty
        }
    }

    Context '-Bucket parameter' {
        It "returns the same content for -Bucket 'PhishResistant' as the .PhishResistant property of the default call" {
            $full = Get-MtZtaAuthMethodSet
            $phish = Get-MtZtaAuthMethodSet -Bucket 'PhishResistant'
            (Compare-Object -ReferenceObject $full.PhishResistant -DifferenceObject $phish -SyncWindow 0) | Should -BeNullOrEmpty
        }

        It "returns the same content for -Bucket 'Phishable' as the .Phishable property of the default call" {
            $full = Get-MtZtaAuthMethodSet
            $phish = Get-MtZtaAuthMethodSet -Bucket 'Phishable'
            (Compare-Object -ReferenceObject $full.Phishable -DifferenceObject $phish -SyncWindow 0) | Should -BeNullOrEmpty
        }
    }
}
