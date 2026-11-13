BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    $script:savedGhToken = $env:GH_TOKEN
    $script:savedGitHubToken = $env:GITHUB_TOKEN
}

AfterAll {
    $env:GH_TOKEN = $script:savedGhToken
    $env:GITHUB_TOKEN = $script:savedGitHubToken
    InModuleScope Maester {
        $__MtSession.GitHubConnection = $null
        $__MtSession.GitHubAuthHeader = $null
        $script:__MtPackGitHubTokenSource = $null
    }
}

Describe 'Pack GitHub token: where the token comes from' {
    BeforeEach {
        $env:GH_TOKEN = $null
        $env:GITHUB_TOKEN = $null
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $script:__MtPackGitHubTokenSource = $null
            $script:calls = [System.Collections.Generic.List[object]]::new()
            # Tokens GitHub answers 404 for, as it does for a private repository a token cannot read.
            $script:cannotRead = @()
            $script:anonymousCanRead = $false

            function script:Set-TestGitHubSession {
                param([string] $Token = 'session-token', [string] $ApiBaseUri = 'https://api.github.com', $ExpiresAt)
                $__MtSession.GitHubAuthHeader = @{ Authorization = "Bearer $Token"; Accept = 'application/vnd.github+json' }
                $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; ApiBaseUri = $ApiBaseUri; TokenExpiresAt = $ExpiresAt }
            }

            Mock Get-MtGitHubCliToken { $null }
            Mock Invoke-RestMethod {
                $sent = if ($Headers.ContainsKey('Authorization')) { $Headers['Authorization'] -replace '^Bearer ' } else { $null }
                $script:calls.Add([pscustomobject]@{ Uri = [string]$Uri; Token = $sent })
                $refused = if ($sent) { $sent -in $script:cannotRead } else { -not $script:anonymousCanRead }
                if ($refused) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Not Found', $response)
                }
                [pscustomobject]@{ full_name = 'contoso/pack' }
            }
        }
    }

    It 'uses -Token before everything else, and nothing else with it' {
        $env:GH_TOKEN = 'env-gh'
        $env:GITHUB_TOKEN = 'env-github'
        InModuleScope Maester {
            Set-TestGitHubSession
            Mock Get-MtGitHubCliToken { 'cli-token' }
            $used = $false
            $token = [System.Net.NetworkCredential]::new('', 'parameter-token').SecurePassword

            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack' -Token $token -UsedToken ([ref] $used)

            $used | Should -BeTrue
            $script:calls.Token | Should -Be @('parameter-token')
            Should -Invoke Get-MtGitHubCliToken -Times 0
        }
    }

    It 'does not fall back to another sign-in when -Token cannot read the repository' {
        $env:GH_TOKEN = 'env-gh'
        InModuleScope Maester {
            Set-TestGitHubSession
            Mock Get-MtGitHubCliToken { 'cli-token' }
            $script:cannotRead = @('parameter-token')
            $token = [System.Net.NetworkCredential]::new('', 'parameter-token').SecurePassword

            { Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack' -Token $token } | Should -Throw '*404*-Token*'

            $script:calls.Token | Should -Be @('parameter-token')
        }
    }

    It 'uses the Connect-MtGitHub sign-in before the GitHub CLI and the environment' {
        $env:GH_TOKEN = 'env-gh'
        $env:GITHUB_TOKEN = 'env-github'
        InModuleScope Maester {
            Set-TestGitHubSession
            Mock Get-MtGitHubCliToken { 'cli-token' }

            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack'

            $script:calls.Token | Should -Be @('session-token')
            Should -Invoke Get-MtGitHubCliToken -Times 0
        }
    }

    It 'uses the GitHub CLI before the environment when the session has no sign-in' {
        $env:GH_TOKEN = 'env-gh'
        $env:GITHUB_TOKEN = 'env-github'
        InModuleScope Maester {
            Mock Get-MtGitHubCliToken { 'cli-token' }

            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack'

            $script:calls.Token | Should -Be @('cli-token')
        }
    }

    It 'uses GH_TOKEN before GITHUB_TOKEN' {
        $env:GH_TOKEN = 'env-gh'
        $env:GITHUB_TOKEN = 'env-github'
        InModuleScope Maester {
            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack'
            $script:calls.Token | Should -Be @('env-gh')
        }
    }

    It 'uses GITHUB_TOKEN last' {
        $env:GITHUB_TOKEN = 'env-github'
        InModuleScope Maester {
            $used = $false
            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack' -UsedToken ([ref] $used)
            $script:calls.Token | Should -Be @('env-github')
            $used | Should -BeTrue
        }
    }

    It 'sends no token when there is none' {
        InModuleScope Maester {
            $script:anonymousCanRead = $true
            $used = $true
            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack' -UsedToken ([ref] $used)
            $script:calls.Count | Should -Be 1
            $script:calls[0].Token | Should -BeNullOrEmpty
            $used | Should -BeFalse
        }
    }

    It 'moves to the next sign-in when one cannot read the repository, in order' {
        $env:GH_TOKEN = 'env-gh'
        $env:GITHUB_TOKEN = 'env-github'
        InModuleScope Maester {
            Set-TestGitHubSession
            Mock Get-MtGitHubCliToken { 'cli-token' }
            $script:cannotRead = @('session-token', 'cli-token', 'env-gh')

            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack'

            $script:calls.Token | Should -Be @('session-token', 'cli-token', 'env-gh', 'env-github')
        }
    }

    It 'starts later requests for a repository with the sign-in that read it' {
        InModuleScope Maester {
            Set-TestGitHubSession
            Mock Get-MtGitHubCliToken { 'cli-token' }
            $script:cannotRead = @('session-token')

            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack'
            $null = Invoke-MtPackGitHubRequest -Path 'repos/Contoso/Pack/releases?per_page=30'

            $script:calls.Token | Should -Be @('session-token', 'cli-token', 'cli-token')
            # The name of the source is remembered, never the token.
            $script:__MtPackGitHubTokenSource['contoso/pack'] | Should -Be 'GitHubCli'
        }
    }

    It 'does not send the same token twice when gh answers with GH_TOKEN' {
        $env:GH_TOKEN = 'env-gh'
        InModuleScope Maester {
            Mock Get-MtGitHubCliToken { 'env-gh' }
            $script:cannotRead = @('env-gh')

            { Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack' } | Should -Throw

            @($script:calls | Where-Object Token -EQ 'env-gh').Count | Should -Be 1
        }
    }

    It 'does not use a session sign-in to <Case>' -ForEach @(
        @{ Case = 'another GitHub host'; ApiBaseUri = 'https://api.contoso.ghe.com'; ExpiresAt = $null }
        @{ Case = 'github.com that has expired'; ApiBaseUri = 'https://api.github.com'; ExpiresAt = [datetimeoffset]::UtcNow.AddMinutes(-5) }
    ) {
        InModuleScope Maester -Parameters @{ ApiBaseUri = $ApiBaseUri; ExpiresAt = $ExpiresAt } {
            Set-TestGitHubSession -ApiBaseUri $ApiBaseUri -ExpiresAt $ExpiresAt
            $script:anonymousCanRead = $true

            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack'

            $script:calls.Token | Should -BeNullOrEmpty
        }
    }

    It 'does not use the sign-in of a session that is not connected' {
        InModuleScope Maester {
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer stale-token' }
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $false; FailureReason = 'TokenInvalid' }
            $script:anonymousCanRead = $true

            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack'

            $script:calls.Token | Should -BeNullOrEmpty
        }
    }

    It 'sends every request to api.github.com' {
        $env:GH_TOKEN = 'env-gh'
        InModuleScope Maester {
            Set-TestGitHubSession
            $script:cannotRead = @('session-token')
            $null = Invoke-MtPackGitHubRequest -Path '/repos/contoso/pack'
            $script:calls.Uri | Select-Object -Unique | Should -Be 'https://api.github.com/repos/contoso/pack'
        }
    }

    It 'returns $null for 404 with -AllowNotFound, without asking other sources once one has read the repository' {
        $env:GH_TOKEN = 'env-gh'
        InModuleScope Maester {
            Set-TestGitHubSession
            $null = Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack'
            $script:cannotRead = @('session-token')

            Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack/git/ref/tags%2Fv9' -AllowNotFound | Should -BeNullOrEmpty

            $script:calls.Token | Should -Be @('session-token', 'session-token')
        }
    }

    It 'names what was tried, and not GH_TOKEN, when nothing can read the repository' {
        InModuleScope Maester {
            Set-TestGitHubSession
            $script:cannotRead = @('session-token')
            $failure = $null
            try { Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack' } catch { $failure = "$_" }
            $failure | Should -BeLike '*404 Not Found*the Connect-MtGitHub sign-in*-Token*'
            $failure | Should -Not -Match 'set GH_TOKEN'
            $failure | Should -Not -Match 'session-token'
        }
    }

    It 'tells someone with no sign-in how to reach a private repository' {
        InModuleScope Maester {
            { Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack' } | Should -Throw '*private repository*gh auth login*-Token*'
        }
    }

    It 'stops at a rate limit instead of trying the next sign-in' {
        $env:GH_TOKEN = 'env-gh'
        InModuleScope Maester {
            Mock Invoke-RestMethod {
                $script:calls.Add([pscustomobject]@{ Uri = [string]$Uri; Token = $Headers['Authorization'] })
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('API rate limit exceeded', $response)
            }
            Set-TestGitHubSession

            { Invoke-MtPackGitHubRequest -Path 'repos/contoso/pack' } | Should -Throw '*rate limit*Wait for the limit to reset*'

            $script:calls.Count | Should -Be 1
        }
    }
}

Describe 'Pack GitHub token: the -Token parameter' {
    It '<Command> takes -Token as a SecureString' -ForEach @(
        @{ Command = 'Install-MtPack' }
        @{ Command = 'Update-MtPack' }
        @{ Command = 'Restore-MtPack' }
    ) {
        $parameter = (Get-Command $Command).Parameters['Token']
        $parameter | Should -Not -BeNullOrEmpty
        $parameter.ParameterType | Should -Be ([securestring])
    }

    It 'is passed to every GitHub request of an install' {
        InModuleScope Maester {
            $script:tokens = [System.Collections.Generic.List[object]]::new()
            Mock Invoke-MtPackGitHubRequest {
                $script:tokens.Add($Token)
                switch -Wildcard ($Path) {
                    'repos/contoso/pack' { [pscustomobject]@{ id = 7; full_name = 'contoso/pack'; default_branch = 'main'; owner = [pscustomobject]@{ id = 9; login = 'contoso' } } }
                    'repos/contoso/pack/releases*' { , @() }
                    'repos/contoso/pack/commits/*' { [pscustomobject]@{ sha = 'c' * 40 } }
                    '*/zipball/*' { throw 'stop after the download was asked for' }
                }
            }
            $token = [System.Net.NetworkCredential]::new('', 'parameter-token').SecurePassword

            { Get-MtPackCandidate -Source 'contoso/pack' -Token $token -IncludeRecent } | Should -Throw '*stop after the download*'

            $script:tokens.Count | Should -BeGreaterThan 2
            foreach ($t in $script:tokens) { [object]::ReferenceEquals($t, $token) | Should -BeTrue }
        }
    }

    It 'is not sent to GitHub requests when it was not given' {
        InModuleScope Maester {
            Mock Invoke-MtPackGitHubRequest { throw 'stop' }
            { Get-MtPackCandidate -Source 'contoso/pack' } | Should -Throw
            Should -Invoke Invoke-MtPackGitHubRequest -ParameterFilter { $null -eq $Token }
        }
    }
}

Describe 'Pack GitHub token: Get-MtSession' {
    It 'does not return the session sign-in the pack commands use' {
        InModuleScope Maester {
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer session-token' }
            try {
                (Get-MtSession).GitHubAuthHeader['Authorization'] | Should -Be '<redacted>'
                (Get-MtSession).Keys | Should -Not -Contain '__MtPackGitHubTokenSource'
            } finally {
                $__MtSession.GitHubAuthHeader = $null
            }
        }
    }
}
