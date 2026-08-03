BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Request-MtGitHubAppOrganizationInstall' {
    BeforeEach {
        $script:readHostCallCount = 0
        Mock Get-MtUserInteractive -ModuleName Maester { $true }
    }

    It 'Explains the install step, opens the browser only after confirmation, and returns true' {
        Mock Read-Host -ModuleName Maester {
            $script:readHostCallCount++
            if ($script:readHostCallCount -eq 1) { return 'Y' }
            return ''
        }
        Mock Open-MtBrowserUrl -ModuleName Maester { $true }

        InModuleScope Maester {
            $result = Request-MtGitHubAppOrganizationInstall -Organization 'myorg' -InstallUrl 'https://github.com/apps/maester-cli/installations/new' -Reason 'forbidden' 6>$null
            $result | Should -BeTrue
        }

        Should -Invoke Open-MtBrowserUrl -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://github.com/apps/maester-cli/installations/new'
        }
        Should -Invoke Read-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Prompt -eq 'Open the GitHub App install page now? [Y/n]'
        }
        Should -Invoke Read-Host -ModuleName Maester -Times 2 -Exactly
    }

    It 'Defaults to opening the browser when the user presses Enter at the confirmation prompt' {
        Mock Read-Host -ModuleName Maester { '' }
        Mock Open-MtBrowserUrl -ModuleName Maester { $true }

        InModuleScope Maester {
            $result = Request-MtGitHubAppOrganizationInstall -Organization 'myorg' -InstallUrl 'https://github.com/apps/maester-cli/installations/new' -Reason 'forbidden' 6>$null
            $result | Should -BeTrue
        }

        Should -Invoke Open-MtBrowserUrl -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://github.com/apps/maester-cli/installations/new'
        }
        Should -Invoke Read-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Prompt -eq 'Open the GitHub App install page now? [Y/n]'
        }
        Should -Invoke Read-Host -ModuleName Maester -Times 2 -Exactly
    }

    It 'Does not open the browser when the user declines and returns false' {
        Mock Read-Host -ModuleName Maester { 'N' }
        Mock Open-MtBrowserUrl -ModuleName Maester { throw 'Browser must not open when the user declines.' }

        InModuleScope Maester {
            $result = Request-MtGitHubAppOrganizationInstall -Organization 'myorg' -InstallUrl 'https://github.com/apps/maester-cli/installations/new' -Reason 'forbidden' 6>$null
            $result | Should -BeFalse
        }

        Should -Invoke Open-MtBrowserUrl -ModuleName Maester -Times 0 -Exactly
        Should -Invoke Read-Host -ModuleName Maester -Times 1 -Exactly
    }

    It 'Returns false without prompting in non-interactive sessions' {
        Mock Get-MtUserInteractive -ModuleName Maester { $false }
        Mock Read-Host -ModuleName Maester { throw 'Read-Host must not be called in non-interactive sessions.' }
        Mock Open-MtBrowserUrl -ModuleName Maester { throw 'Browser must not open in non-interactive sessions.' }

        InModuleScope Maester {
            $result = Request-MtGitHubAppOrganizationInstall -Organization 'myorg' -InstallUrl 'https://github.com/apps/maester-cli/installations/new' 6>$null
            $result | Should -BeFalse
        }

        Should -Invoke Read-Host -ModuleName Maester -Times 0 -Exactly
        Should -Invoke Open-MtBrowserUrl -ModuleName Maester -Times 0 -Exactly
    }
}
