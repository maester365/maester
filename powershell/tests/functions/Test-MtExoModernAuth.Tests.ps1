Describe 'Test-MtExoModernAuth' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        Mock -ModuleName Maester Test-MtConnection { return $true }
    }

    Context 'Modern authentication enabled (boolean $true)' {
        BeforeAll {
            Mock -ModuleName Maester Get-MtExo {
                return [PSCustomObject]@{
                    OAuth2ClientProfileEnabled = $true
                }
            }
        }

        It 'Should return $true when OAuth2ClientProfileEnabled is $true' {
            Test-MtExoModernAuth | Should -BeTrue
        }
    }

    Context 'Modern authentication disabled (boolean $false)' {
        BeforeAll {
            Mock -ModuleName Maester Get-MtExo {
                return [PSCustomObject]@{
                    OAuth2ClientProfileEnabled = $false
                }
            }
        }

        It 'Should return $false when OAuth2ClientProfileEnabled is $false' {
            Test-MtExoModernAuth | Should -BeFalse
        }
    }

    Context 'Modern authentication enabled (string "True")' {
        BeforeAll {
            Mock -ModuleName Maester Get-MtExo {
                return [PSCustomObject]@{
                    OAuth2ClientProfileEnabled = 'True'
                }
            }
        }

        It 'Should return $true when OAuth2ClientProfileEnabled is the string "True"' {
            Test-MtExoModernAuth | Should -BeTrue
        }
    }

    Context 'Modern authentication disabled (string "False")' {
        BeforeAll {
            Mock -ModuleName Maester Get-MtExo {
                return [PSCustomObject]@{
                    OAuth2ClientProfileEnabled = 'False'
                }
            }
        }

        It 'Should return $false when OAuth2ClientProfileEnabled is the string "False"' {
            Test-MtExoModernAuth | Should -BeFalse
        }
    }
}
