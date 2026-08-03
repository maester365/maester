Describe 'Set-MtGitHubActionsSecret' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    Context 'When the GitHub CLI is unavailable' {
        It 'Returns $false when gh is not on PATH' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Command { $null } -ParameterFilter { $Name -eq 'gh' }

                $result = Set-MtGitHubActionsSecret -GitHubRepository 'contoso/repo' -ClientId 'cid' -TenantId 'tid' -WarningAction SilentlyContinue
                $result | Should -Be $false
            }
        }
    }

    Context 'When gh is installed but not authenticated' {
        It 'Returns $false when gh auth status exits non-zero' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Command { @{ Name = 'gh' } } -ParameterFilter { $Name -eq 'gh' }
                Mock gh { $global:LASTEXITCODE = 1; 'not logged in' }

                $result = Set-MtGitHubActionsSecret -GitHubRepository 'contoso/repo' -ClientId 'cid' -TenantId 'tid' -WarningAction SilentlyContinue
                $result | Should -Be $false
            }
        }
    }

    Context 'When gh secret set succeeds for both secrets' {
        It 'Returns $true' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Command { @{ Name = 'gh' } } -ParameterFilter { $Name -eq 'gh' }
                # First call (`gh auth status`) and subsequent (`gh secret set`) all exit 0.
                Mock gh { $global:LASTEXITCODE = 0; 'ok' }

                $result = Set-MtGitHubActionsSecret -GitHubRepository 'contoso/repo' -ClientId 'cid' -TenantId 'tid' 6>$null
                $result | Should -Be $true
            }
        }
    }

    Context 'When a gh secret set call fails' {
        It 'Returns $false when the underlying gh call exits non-zero' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Command { @{ Name = 'gh' } } -ParameterFilter { $Name -eq 'gh' }
                # auth status passes, then the first `gh secret set` fails.
                $script:ghCallCount = 0
                Mock gh {
                    $script:ghCallCount++
                    if ($script:ghCallCount -eq 1) {
                        $global:LASTEXITCODE = 0  # gh auth status
                        return 'logged in'
                    }
                    $global:LASTEXITCODE = 1  # gh secret set
                    return 'permission denied'
                }

                $result = Set-MtGitHubActionsSecret -GitHubRepository 'contoso/repo' -ClientId 'cid' -TenantId 'tid' -WarningAction SilentlyContinue 6>$null
                $result | Should -Be $false
            }
        }
    }
}
