Describe 'Get-MtGitHubRepoFromString' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    Context 'Shorthand input' {
        It 'Parses an owner/repo shorthand' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository 'maester365/maester'
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }

        It 'Trims surrounding whitespace' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository '  maester365/maester  '
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }
    }

    Context 'URL input' {
        It 'Parses an HTTPS GitHub URL' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository 'https://github.com/maester365/maester'
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }

        It 'Parses an HTTPS GitHub URL with .git suffix' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository 'https://github.com/maester365/maester.git'
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }

        It 'Parses an HTTPS GitHub URL with a trailing slash' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository 'https://github.com/maester365/maester/'
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }

        It 'Parses an HTTPS GitHub URL with a trailing path (e.g. /tree/main)' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository 'https://github.com/maester365/maester/tree/main'
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }

        It 'Parses an HTTPS GitHub URL with www. prefix' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository 'https://www.github.com/maester365/maester'
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }

        It 'Parses an SSH (scp-style) GitHub URL' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository 'git@github.com:maester365/maester.git'
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }

        It 'Parses an ssh:// GitHub URL' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtGitHubRepoFromString -Repository 'ssh://git@github.com/maester365/maester.git'
                $result.Organization | Should -Be 'maester365'
                $result.Repository | Should -Be 'maester'
            }
        }
    }

    Context 'Invalid input' {
        It 'Throws for an empty string (Mandatory parameter validation)' {
            InModuleScope -ModuleName 'Maester' {
                { Get-MtGitHubRepoFromString -Repository '' } | Should -Throw
            }
        }

        It 'Returns $null for whitespace only' {
            InModuleScope -ModuleName 'Maester' {
                Get-MtGitHubRepoFromString -Repository '   ' | Should -BeNullOrEmpty
            }
        }

        It 'Returns $null when no repo segment is present' {
            InModuleScope -ModuleName 'Maester' {
                Get-MtGitHubRepoFromString -Repository 'maester365' | Should -BeNullOrEmpty
            }
        }

        It 'Returns $null for a lookalike host that ends with github.com (e.g. evilgithub.com)' {
            InModuleScope -ModuleName 'Maester' {
                Get-MtGitHubRepoFromString -Repository 'https://evilgithub.com/maester365/repo' | Should -BeNullOrEmpty
            }
        }

        It 'Returns $null for a host that has github.com as a subdomain prefix (e.g. github.com.attacker.com)' {
            InModuleScope -ModuleName 'Maester' {
                Get-MtGitHubRepoFromString -Repository 'https://github.com.attacker.com/maester365/repo' | Should -BeNullOrEmpty
            }
        }
    }
}
