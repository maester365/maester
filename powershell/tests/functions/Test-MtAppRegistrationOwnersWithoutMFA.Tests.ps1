BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Test-MtAppRegistrationOwnersWithoutMFA' -Tag 'Unit' {
    BeforeEach {
        # Owners 1 to 20 have MFA registered, owners 21 to 25 do not.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            1..25 | ForEach-Object {
                [pscustomobject]@{
                    id                = "owner-$_"
                    userPrincipalName = "owner$_@contoso.com"
                    userDisplayName   = "Owner $_"
                    isMfaRegistered   = ($_ -le 20)
                }
            }
        } -ParameterFilter { $RelativeUri -like 'reports/authenticationMethods/userRegistrationDetails*' }

        Mock -ModuleName Maester Invoke-MtGraphRequest {
            1..25 | ForEach-Object {
                [pscustomobject]@{
                    '@odata.type'     = '#microsoft.graph.user'
                    id                = "owner-$_"
                    displayName       = "Owner $_"
                    userPrincipalName = "owner$_@contoso.com"
                }
            }
        } -ParameterFilter { $RelativeUri -eq 'applications/app-1/owners' }

        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'reads every owner of an app whose expanded owners stop at the 20 that $expand returns' {
        # $expand returns at most 20 items of a directory object relationship, here owners 1 to 20.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                id          = 'app-1'
                appId       = '11111111-1111-1111-1111-111111111111'
                displayName = 'App with 25 owners'
                owners      = @(1..20 | ForEach-Object {
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = "owner-$_"
                            displayName       = "Owner $_"
                            userPrincipalName = "owner$_@contoso.com"
                        }
                    })
            }
        } -ParameterFilter { $RelativeUri -eq 'applications?$expand=owners' }

        InModuleScope Maester {
            Test-MtAppRegistrationOwnersWithoutMFA | Should -BeFalse
        }

        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter { $RelativeUri -eq 'applications/app-1/owners' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $Result -match '\| Owner 25 \|' }
    }

    It 'does not read the owners again when $expand returns fewer than 20' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                id          = 'app-1'
                appId       = '11111111-1111-1111-1111-111111111111'
                displayName = 'App with 19 owners'
                owners      = @(1..19 | ForEach-Object {
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = "owner-$_"
                            displayName       = "Owner $_"
                            userPrincipalName = "owner$_@contoso.com"
                        }
                    })
            }
        } -ParameterFilter { $RelativeUri -eq 'applications?$expand=owners' }

        InModuleScope Maester {
            Test-MtAppRegistrationOwnersWithoutMFA | Should -BeTrue
        }

        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 0 -ParameterFilter { $RelativeUri -eq 'applications/app-1/owners' }
    }
}
