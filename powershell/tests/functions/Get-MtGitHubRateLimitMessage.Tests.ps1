BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Get-MtGitHubRateLimitMessage' {
    Context 'Non-rate-limit responses' {
        It 'Returns $null for status codes outside 403/429' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{ StatusCode = 500; Headers = @{} }
                $ex = [System.Exception]::new('Server error')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                Get-MtGitHubRateLimitMessage -ErrorRecord $err | Should -BeNullOrEmpty
            }
        }

        It 'Returns $null for 403 without rate-limit headers' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                Get-MtGitHubRateLimitMessage -ErrorRecord $err | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Malformed headers' {
        It 'Returns $null when x-ratelimit-remaining is not a number and no retry-after header is set' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{
                    StatusCode = 403
                    Headers    = @{ 'x-ratelimit-remaining' = 'not-a-number' }
                }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                { Get-MtGitHubRateLimitMessage -ErrorRecord $err } | Should -Not -Throw
                Get-MtGitHubRateLimitMessage -ErrorRecord $err | Should -BeNullOrEmpty
            }
        }

        It 'Returns primary rate-limit message with "Resets at: unknown" when remaining is 0 and reset is malformed' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{
                    StatusCode = 403
                    Headers    = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = 'not-a-number' }
                }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                $msg = Get-MtGitHubRateLimitMessage -ErrorRecord $err
                $msg | Should -Match 'rate limit'
                $msg | Should -Match 'Resets at: unknown'
            }
        }
    }

    Context 'Valid rate-limit headers' {
        It 'Returns primary rate-limit message with parsed reset time when remaining=0 and reset is valid' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{
                    StatusCode = 403
                    Headers    = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = '9999999999' }
                }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                $msg = Get-MtGitHubRateLimitMessage -ErrorRecord $err
                $msg | Should -Match '^GitHub API rate limit encountered \(HTTP 403\)\. Resets at: '
                $msg | Should -Not -Match 'unknown'
            }
        }

        It 'Returns secondary rate-limit message when retry-after is present' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{
                    StatusCode = 429
                    Headers    = @{ 'retry-after' = '30' }
                }
                $ex = [System.Exception]::new('Too Many Requests')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                $msg = Get-MtGitHubRateLimitMessage -ErrorRecord $err
                $msg | Should -Match 'secondary rate limit'
                $msg | Should -Match 'Retry after: 30s'
            }
        }
    }

    Context 'Body-fallback secondary rate-limit detection' {
        It 'Returns secondary rate-limit message for 403 when body mentions secondary rate limit and no retry-after header is present' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                $err.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"message":"You have exceeded a secondary rate limit. Please wait a few minutes before you try again."}')
                $msg = Get-MtGitHubRateLimitMessage -ErrorRecord $err
                $msg | Should -Match '^GitHub secondary rate limit encountered \(HTTP 403\)\.'
                $msg | Should -Match 'Retry after at least 60s'
            }
        }

        It 'Returns secondary rate-limit message for 429 when body mentions abuse detection and no retry-after header is present' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{ StatusCode = 429; Headers = @{} }
                $ex = [System.Exception]::new('Too Many Requests')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                $err.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"message":"Triggered abuse detection mechanism."}')
                $msg = Get-MtGitHubRateLimitMessage -ErrorRecord $err
                $msg | Should -Match '^GitHub secondary rate limit encountered \(HTTP 429\)\.'
                $msg | Should -Match 'Retry after at least 60s'
            }
        }

        It 'Still returns $null for 403 when body has unrelated message and no rate-limit headers' {
            InModuleScope Maester {
                $resp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                $err = [System.Management.Automation.ErrorRecord]::new($ex, 'id', 'NotSpecified', $null)
                $err.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"message":"Resource not accessible by personal access token"}')
                Get-MtGitHubRateLimitMessage -ErrorRecord $err | Should -BeNullOrEmpty
            }
        }
    }
}
