Describe 'Test-MtEntraIDConnectSsso' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    BeforeEach {
        $script:SkippedBecause = $null
        $script:SkippedCustomReason = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($SkippedBecause, $SkippedCustomReason)
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedCustomReason = $SkippedCustomReason
        }
    }

    It 'skips when the DeviceInfo hunting table is unavailable' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri, $Body)

            if ($RelativeUri -eq 'organization') {
                return [PSCustomObject]@{ onPremisesSyncEnabled = $true }
            }
            if ($Body -match 'IdentityLogonEvents') {
                return [PSCustomObject]@{
                    results = @([PSCustomObject]@{ ColumnName = 'LogonType' })
                }
            }
            if ($Body -match 'DeviceInfo') {
                throw "POST https://graph.microsoft.com/beta/security/runHuntingQuery HTTP/1.1 400 Bad Request: 'getschema' operator: Failed to resolve table or column expression named 'DeviceInfo'."
            }
        }

        Test-MtEntraIDConnectSsso | Should -BeNull
        $script:SkippedBecause | Should -Be 'Custom'
        $script:SkippedCustomReason | Should -BeLike '*IdentityLogonEvents and DeviceInfo*'
    }

    It 'keeps unrelated bad requests classified as errors' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri, $Body)

            if ($RelativeUri -eq 'organization') {
                return [PSCustomObject]@{ onPremisesSyncEnabled = $true }
            }
            if ($Body -match 'IdentityLogonEvents') {
                throw 'POST https://graph.microsoft.com/beta/security/runHuntingQuery HTTP/1.1 400 Bad Request: The query is invalid for another reason.'
            }
        }

        Test-MtEntraIDConnectSsso | Should -BeNull
        $script:SkippedBecause | Should -Be 'Error'
        $script:SkippedCustomReason | Should -BeNull
    }
}
