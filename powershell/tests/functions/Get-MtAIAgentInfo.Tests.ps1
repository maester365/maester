BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Az.Accounts is optional; provide a stub so Get-AzAccessToken can be mocked when it is not installed.
    if (-not (Get-Command Get-AzAccessToken -ErrorAction SilentlyContinue)) {
        function global:Get-AzAccessToken {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ResourceUrl', Justification = 'Stub signature only; Mock binds -ResourceUrl from it.')]
            param($ResourceUrl)
        }
        $script:removeAzStub = $true
    }
}

AfterAll {
    if ($script:removeAzStub) {
        Remove-Item -Path Function:\Get-AzAccessToken -ErrorAction SilentlyContinue
    }
}

Describe 'Get-MtAIAgentInfo failure reasons' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.AIAgentInfo = $null
            $__MtSession.AIAgentInfoError = $null
            $__MtSession.DataverseApiBase = 'https://org123.api.crm.dynamics.com/api/data/v9.2'
            $__MtSession.DataverseResourceUrl = 'https://org123.crm.dynamics.com'
            $__MtSession.DataverseEnvironmentId = 'org123.crm.dynamics.com'
        }
        Mock -ModuleName Maester Get-AzAccessToken { [pscustomobject]@{ Token = 'token' } }
    }

    AfterAll {
        InModuleScope Maester {
            $__MtSession.AIAgentInfo = $null
            $__MtSession.AIAgentInfoError = $null
            $__MtSession.DataverseApiBase = $null
            $__MtSession.DataverseResourceUrl = $null
            $__MtSession.DataverseEnvironmentId = $null
        }
    }

    It 'Reports a missing Dataverse privilege as a skip reason without writing a warning (#2289)' {
        Mock -ModuleName Maester Invoke-RestMethod {
            $exception = [System.Exception]::new('Response status code does not indicate success: 403 (Forbidden).')
            $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{ StatusCode = 403 })
            $record = [System.Management.Automation.ErrorRecord]::new($exception, 'WebCmdletWebResponseException', 'InvalidOperation', $null)
            $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"0x80040220","message":"Principal user is missing prvReadbot privilege on OTC=10154 for entity ''bot''."}}')
            throw $record
        }

        $agents = InModuleScope Maester { Get-MtAIAgentInfo -WarningVariable warnings -WarningAction SilentlyContinue; $script:warnings = $warnings }
        $agents | Should -BeNullOrEmpty
        InModuleScope Maester { $script:warnings } | Should -BeNullOrEmpty

        $reason = InModuleScope Maester { Get-MtAIAgentSkippedReason -TestId 'MT.1113' }
        $reason | Should -Match 'does not have permission to read Copilot Studio agents'
        $reason | Should -Match 'HTTP 403'
        $reason | Should -Match 'missing prvReadbot privilege'
        $reason | Should -Not -Match '"error"'
        $reason | Should -Match 'https://maester.dev/docs/tests/MT.1113'
    }

    It 'Reports when the environment has no Copilot Studio agents' {
        Mock -ModuleName Maester Invoke-RestMethod { [pscustomobject]@{ value = @() } }

        InModuleScope Maester { Get-MtAIAgentInfo } | Should -BeNullOrEmpty

        InModuleScope Maester { Get-MtAIAgentSkippedReason -TestId 'MT.1117' } | Should -Match 'No Copilot Studio agents were found'
    }

    It 'Falls back to the generic prerequisites message when no reason was recorded' {
        InModuleScope Maester { Get-MtAIAgentSkippedReason -TestId 'MT.1113' } | Should -Match '^No Copilot Studio agent data available\.'
    }
}
