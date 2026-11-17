Describe 'CIS M365 access review checks' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name @(
            'Test-MtCisGuestAccessReviews',
            'Test-MtCisPrivilegedRoleAccessReviews'
        )

        function New-GuestAccessReview {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper creates an in-memory fixture and has no external side effects.')]
            param([string] $DisplayName)

            return [pscustomobject]@{
                displayName = $DisplayName
                status = 'InProgress'
                scope = [pscustomobject]@{
                    query = "/users?`$filter=userType eq 'Guest'"
                    resourceScopes = @()
                    principalScopes = @()
                }
                reviewers = @([pscustomobject]@{ query = '/users/reviewer' })
                stageSettings = @()
                settings = [pscustomobject]@{
                    mailNotificationsEnabled = $true
                    reminderNotificationsEnabled = $true
                    instanceDurationInDays = 14
                    justificationRequiredOnApproval = $true
                    autoApplyDecisionsEnabled = $true
                    defaultDecisionEnabled = $true
                    defaultDecision = 'Deny'
                    recurrence = [pscustomobject]@{
                        pattern = [pscustomobject]@{ type = 'weekly'; interval = 1 }
                        range = [pscustomobject]@{ type = 'noEnd'; startDate = '2026-01-01' }
                    }
                }
            }
        }

        function New-RoleAccessReview {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper creates an in-memory fixture and has no external side effects.')]
            param(
                [string] $DisplayName,
                [string] $RoleId,
                [string] $StartDate
            )

            return [pscustomobject]@{
                displayName = $DisplayName
                status = 'InProgress'
                scope = [pscustomobject]@{
                    query = $null
                    resourceScopes = @([pscustomobject]@{
                            query = "/roleManagement/directory/roleDefinitions/$RoleId"
                        })
                    principalScopes = @(
                        [pscustomobject]@{ query = '/v1.0/users' }
                        [pscustomobject]@{ query = '/v1.0/groups' }
                    )
                }
                reviewers = @([pscustomobject]@{ query = '/users/reviewer' })
                stageSettings = @()
                settings = [pscustomobject]@{
                    mailNotificationsEnabled = $true
                    reminderNotificationsEnabled = $true
                    instanceDurationInDays = 14
                    justificationRequiredOnApproval = $true
                    autoApplyDecisionsEnabled = $true
                    defaultDecisionEnabled = $false
                    defaultDecision = 'Approve'
                    recurrence = [pscustomobject]@{
                        pattern = [pscustomobject]@{ type = 'absoluteMonthly'; interval = 1 }
                        range = [pscustomobject]@{ type = 'noEnd'; startDate = $StartDate }
                    }
                }
            }
        }
    }

    BeforeEach {
        $script:reviews = @()
        $script:result = $null

        Mock -ModuleName Maester Invoke-MtGraphRequest { return $script:reviews }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result)
            $script:result = $Result
        }
    }

    It 'escapes guest review names and preserves replacement characters in the result table' {
        $script:reviews = @(
            New-GuestAccessReview -DisplayName 'Maester lab 5.3.2 guests | $& $$'
        )

        Test-MtCisGuestAccessReviews | Should -BeTrue
        $script:result | Should -BeLike '*Maester lab 5.3.2 guests \| $& $$*'
    }

    It 'fails guest reviews that recur less often than monthly' {
        $patterns = @(
            [pscustomobject]@{ Type = 'weekly'; Interval = 5 }
            [pscustomobject]@{ Type = 'absoluteMonthly'; Interval = 2 }
        )

        foreach ($pattern in $patterns) {
            $review = New-GuestAccessReview -DisplayName 'Infrequent guest review'
            $review.settings.recurrence.pattern.type = $pattern.Type
            $review.settings.recurrence.pattern.interval = $pattern.Interval
            $script:reviews = @($review)

            Test-MtCisGuestAccessReviews | Should -BeFalse
            $script:result | Should -BeLike '*Weekly or monthly*'
        }
    }

    It 'accepts active role reviews with disabled default decisions and future date-only start dates' {
        $roleIds = @(
            '62e90394-69f5-4237-9190-012177145e10',
            '29232cdf-9323-42fd-ade2-1d097af3e4de',
            'f28a1f50-f6e7-4571-818b-6a12f2af6b6c',
            '69091246-20e8-4a56-aa4d-066075b2a7a8',
            '194ae4cb-b126-40b2-bd5b-6091b380977d',
            'e8611ab8-c189-46e8-94e1-60213ab1f814'
        )
        $startDate = [datetime]::UtcNow.Date.AddDays(1).ToString('yyyy-MM-dd')
        $script:reviews = @(
            foreach ($roleId in $roleIds) {
                New-RoleAccessReview -DisplayName 'Maester role review | $& $$' -RoleId $roleId -StartDate $startDate
            }
        )

        Test-MtCisPrivilegedRoleAccessReviews | Should -BeTrue
        $script:result | Should -BeLike '*Maester role review \| $& $$*'
    }

    It 'fails role reviews that recur less often than monthly' {
        $roleIds = @(
            '62e90394-69f5-4237-9190-012177145e10',
            '29232cdf-9323-42fd-ade2-1d097af3e4de',
            'f28a1f50-f6e7-4571-818b-6a12f2af6b6c',
            '69091246-20e8-4a56-aa4d-066075b2a7a8',
            '194ae4cb-b126-40b2-bd5b-6091b380977d',
            'e8611ab8-c189-46e8-94e1-60213ab1f814'
        )
        $patterns = @(
            [pscustomobject]@{ Type = 'weekly'; Interval = 5 }
            [pscustomobject]@{ Type = 'absoluteMonthly'; Interval = 2 }
        )

        foreach ($pattern in $patterns) {
            $script:reviews = @(
                foreach ($roleId in $roleIds) {
                    $review = New-RoleAccessReview -DisplayName 'Infrequent role review' -RoleId $roleId -StartDate '2026-01-01'
                    $review.settings.recurrence.pattern.type = $pattern.Type
                    $review.settings.recurrence.pattern.interval = $pattern.Interval
                    $review
                }
            )

            Test-MtCisPrivilegedRoleAccessReviews | Should -BeFalse
            $script:result | Should -BeLike '*Weekly or monthly*'
        }
    }

    It 'ignores role reviews outside the directory role definitions path' {
        $roleIds = @(
            '62e90394-69f5-4237-9190-012177145e10',
            '29232cdf-9323-42fd-ade2-1d097af3e4de',
            'f28a1f50-f6e7-4571-818b-6a12f2af6b6c',
            '69091246-20e8-4a56-aa4d-066075b2a7a8',
            '194ae4cb-b126-40b2-bd5b-6091b380977d',
            'e8611ab8-c189-46e8-94e1-60213ab1f814'
        )
        $script:reviews = @(
            foreach ($roleId in $roleIds) {
                $review = New-RoleAccessReview -DisplayName 'Non-directory role review' -RoleId $roleId -StartDate '2026-01-01'
                $review.scope.resourceScopes[0].query = "/roleManagement/other/roleDefinitions/$roleId"
                $review
            }
        )

        Test-MtCisPrivilegedRoleAccessReviews | Should -BeFalse
    }
}
