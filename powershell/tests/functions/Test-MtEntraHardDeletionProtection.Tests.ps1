Describe 'Test-MtEntraHardDeletionProtection' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtEntraHardDeletionProtection

        $script:UserId = '11111111-1111-1111-1111-111111111111'
        $script:GroupId = '22222222-2222-2222-2222-222222222222'
    }

    BeforeEach {
        $State = @{
            Detail = $null; Investigate = $false; Listed = @(); Protected = @{}; ObjectById = @{}; DeletedById = @{}; Wrap = $false
        }
        # The exception Invoke-MtGraphRequest lets through for a single request that Graph answers with 404.
        $NotFoundError = [Microsoft.PowerShell.Commands.HttpResponseException]::new(
            'Response status code does not indicate success: NotFound (Not Found).',
            [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
        )

        Mock -ModuleName Maester Add-MtTestResultDetail -MockWith {
            param($Result, [switch] $Investigate)
            $State.Detail = $Result
            $State.Investigate = [bool]$Investigate
        }.GetNewClosure()
        Mock -ModuleName Maester Invoke-MtGraphRequest -MockWith {
            param($RelativeUri)
            if ($RelativeUri -match '^directory/deletedItems/microsoft\.graph\.[A-Za-z]+/[^/]+$') {
                $deleted = $State.DeletedById[$RelativeUri.Split('/')[-1]]
                if ($null -eq $deleted) { throw $(if ($State.Wrap) { [System.InvalidOperationException]::new('Request failed.', $NotFoundError) } else { $NotFoundError }) }
                return $deleted
            }
            if ($RelativeUri -match '^(users|groups|applications|servicePrincipals)/[^/]+$') {
                $object = $State.ObjectById[$RelativeUri.Split('/')[-1]]
                if ($null -eq $object) { throw $(if ($State.Wrap) { [System.InvalidOperationException]::new('Request failed.', $NotFoundError) } else { $NotFoundError }) }
                return $object
            }
            $key = [string]$RelativeUri
            if ($State.Protected.Keys -contains $key) { return $State.Protected[$key] }
            return @()
        }.GetNewClosure()
    }

    AfterEach {
        if ($null -ne $State.Detail) {
            $State.Detail | Should -Not -Match '`[^`]+`'
        }
    }

    Context 'No objects are listed' {
        It 'is Investigate and says nothing is protected yet' {
            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeNullOrEmpty
            $State.Investigate | Should -BeTrue
            $State.Detail | Should -Match 'verified manually'
            $State.Detail | Should -Match 'No object in Microsoft Entra has Hard Deletion Protection yet'
        }

        It 'is Investigate and lists the protected objects it finds' {
            $State.Protected['users'] = @([pscustomobject]@{ id = $script:UserId; displayName = 'Admin One' })
            $State.Protected['directory/deletedItems/microsoft.graph.group'] = @(
                [pscustomobject]@{ id = $script:GroupId; displayName = 'Deleted group' }
            )

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeNullOrEmpty
            $State.Investigate | Should -BeTrue
            $State.Detail | Should -Match '2 object\(s\) have Hard Deletion Protection'
            $State.Detail | Should -Match "User \| $($script:UserId) \| Admin One \| Active"
            $State.Detail | Should -Match "Group \| $($script:GroupId) \| Deleted group \| Soft deleted"
        }

        It 'counts an object once when it shows up as both active and soft deleted' {
            $State.Protected['users'] = @([pscustomobject]@{ id = $script:UserId; displayName = 'Admin One' })
            $State.Protected['directory/deletedItems/microsoft.graph.user'] = @(
                [pscustomobject]@{ id = $script:UserId; displayName = 'Admin One' }
            )

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeNullOrEmpty
            $State.Detail | Should -Match '1 object\(s\) have Hard Deletion Protection'
            $State.Detail | Should -Match 'Admin One \| Active or soft deleted'
        }
    }

    Context 'Objects are listed' {
        It 'passes when every listed object is protected and nothing else is' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = $script:UserId })
            $State.ObjectById[$script:UserId] = [pscustomobject]@{
                id = $script:UserId; displayName = 'Admin One'; isHardDeleteProtectionEnabled = $true
            }
            $State.Protected['users'] = @([pscustomobject]@{ id = $script:UserId; displayName = 'Admin One' })

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeTrue
            $State.Investigate | Should -BeFalse
            $State.Detail | Should -Match 'Well done'
        }

        It 'is Investigate when listed objects pass but other protected objects are not listed' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = $script:UserId })
            $State.ObjectById[$script:UserId] = [pscustomobject]@{
                id = $script:UserId; displayName = 'Admin One'; isHardDeleteProtectionEnabled = $true
            }
            $State.Protected['users'] = @(
                [pscustomobject]@{ id = $script:UserId; displayName = 'Admin One' }
                [pscustomobject]@{ id = $script:GroupId; displayName = 'Other admin' }
            )

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeNullOrEmpty
            $State.Investigate | Should -BeTrue
            $State.Detail | Should -Match 'Other admin'
            $State.Detail | Should -Not -Match 'Admin One \|'
        }

        It 'fails and lists an unprotected object, even when other protected objects are not listed' {
            $State.Listed = @([pscustomobject]@{ Type = 'user'; Id = $script:UserId })
            $State.ObjectById[$script:UserId] = [pscustomobject]@{
                id = $script:UserId; displayName = 'Plain | User'; isHardDeleteProtectionEnabled = $null
            }
            $State.Protected['groups'] = @([pscustomobject]@{ id = $script:GroupId; displayName = 'Some group' })

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeFalse
            $State.Investigate | Should -BeFalse
            $State.Detail | Should -Match '1 of 1 listed object'
            $State.Detail | Should -Match 'User \| 11111111-1111-1111-1111-111111111111 \| Plain &#124; User \| Not protected'
            $State.Detail | Should -Match 'Some group'
        }

        It 'fails an object that cannot be found' {
            $State.Listed = @([pscustomobject]@{ Type = 'Group'; Id = $script:GroupId })

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeFalse
            $State.Detail | Should -Match 'Not found'
        }

        It 'fails a listed object that is protected but soft deleted' {
            $State.Listed = @([pscustomobject]@{ Type = 'Group'; Id = $script:GroupId })
            $State.DeletedById[$script:GroupId] = [pscustomobject]@{ id = $script:GroupId; displayName = 'Deleted group' }
            $State.Protected['directory/deletedItems/microsoft.graph.group'] = @(
                [pscustomobject]@{ id = $script:GroupId; displayName = 'Deleted group' }
            )

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeFalse
            $State.Detail | Should -Match 'Group \| 22222222-2222-2222-2222-222222222222 \| Deleted group \| Soft deleted'
        }

        It 'reports a listed object that was soft deleted without protection as soft deleted, not as not found' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = $script:UserId })
            $State.DeletedById[$script:UserId] = [pscustomobject]@{ id = $script:UserId; displayName = 'Removed user' }

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeFalse
            $State.Detail | Should -Match 'User \| 11111111-1111-1111-1111-111111111111 \| Removed user \| Soft deleted'
            $State.Detail | Should -Not -Match 'Not found'
        }

        It 'looks for a deleted object only among the deleted items of the listed type' {
            $State.Listed = @([pscustomobject]@{ Type = 'Group'; Id = $script:GroupId })

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeFalse
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'directory/deletedItems/microsoft.graph.group/22222222-2222-2222-2222-222222222222'
            }
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 0 -Exactly -ParameterFilter {
                $RelativeUri -like 'directory/deletedItems/microsoft.graph.*/22222222-2222-2222-2222-222222222222' -and
                $RelativeUri -notlike 'directory/deletedItems/microsoft.graph.group/*'
            }
        }

        It 'reports a 404 that sits on the inner exception as not found' {
            $State.Listed = @([pscustomobject]@{ Type = 'Group'; Id = $script:GroupId })
            $State.Wrap = $true

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeFalse
            $State.Detail | Should -Match 'Group \| 22222222-2222-2222-2222-222222222222 \|  \| Not found'
        }

        It 'rejects an Id that is not a GUID before it calls Graph' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = 'admin@contoso.com' })

            { Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed } |
                Should -Throw '*Id must be the object ID (a GUID)*'
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 0 -Exactly -ParameterFilter {
                $RelativeUri -like 'users/*'
            }
        }

        It 'uses the canonical lower-case form of the Id in the request and in the result' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = '{AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB}' })
            $State.ObjectById['aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb'] = [pscustomobject]@{
                id = 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb'; displayName = 'Mixed case'; isHardDeleteProtectionEnabled = $null
            }

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeFalse
            $State.Detail | Should -MatchExactly 'User \| aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb \| Mixed case \| Not protected'
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -ceq 'users/aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb'
            }
        }

        It 'keeps a protected object in the unlisted table when its Id is listed under another Type' {
            $State.Listed = @([pscustomobject]@{ Type = 'Group'; Id = $script:UserId })
            $State.Protected['users'] = @([pscustomobject]@{ id = $script:UserId; displayName = 'Admin One' })

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeFalse
            $State.Detail | Should -Match 'Group \| 11111111-1111-1111-1111-111111111111 \|  \| Not found'
            $State.Detail | Should -Match 'User \| 11111111-1111-1111-1111-111111111111 \| Admin One \| Active'
        }

        It 'does not list a correctly listed object as unlisted' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = $script:UserId })
            $State.ObjectById[$script:UserId] = [pscustomobject]@{
                id = $script:UserId; displayName = 'Admin One'; isHardDeleteProtectionEnabled = $true
            }
            $State.Protected['users'] = @([pscustomobject]@{ id = $script:UserId; displayName = 'Admin One' })

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeTrue
            $State.Detail | Should -Not -Match 'other object'
        }

        It 'shows the first 25 unlisted objects and the total' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = $script:UserId })
            $State.ObjectById[$script:UserId] = [pscustomobject]@{
                id = $script:UserId; displayName = 'Admin One'; isHardDeleteProtectionEnabled = $true
            }
            $State.Protected['groups'] = @(
                1..30 | ForEach-Object {
                    [pscustomobject]@{ id = ('33333333-3333-3333-3333-{0:D12}' -f $_); displayName = "Group $_" }
                }
            )

            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed | Should -BeNullOrEmpty
            $State.Detail | Should -Match '30 other object\(s\)'
            $State.Detail | Should -Match 'Showing the first 25 of 30 objects'
            $State.Detail | Should -Match 'Group 25 \|'
            $State.Detail | Should -Not -Match 'Group 26 \|'
        }
    }

    Context 'Errors' {
        It 'throws for an invalid object type' {
            $State.Listed = @([pscustomobject]@{ Type = 'Device'; Id = $script:UserId })

            { Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed } |
                Should -Throw '*Type must be User, Group, Application or ServicePrincipal*'
        }

        It 'throws for a Graph error that is not a 404' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = $script:UserId })
            Mock -ModuleName Maester Invoke-MtGraphRequest -MockWith {
                param($RelativeUri)
                if ($RelativeUri -like 'users/*') {
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new(
                        'Response status code does not indicate success: Forbidden (Forbidden).',
                        [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                    )
                }
                return @()
            }

            { Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed } | Should -Throw '*Forbidden*'
        }

        It 'throws, instead of reporting Not found, when the error has no HTTP response' {
            $State.Listed = @([pscustomobject]@{ Type = 'User'; Id = $script:UserId })
            Mock -ModuleName Maester Invoke-MtGraphRequest -MockWith {
                param($RelativeUri)
                if ($RelativeUri -like 'users/*') { throw [System.InvalidOperationException]::new('Batch request failed.') }
                return @()
            }

            { Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed } | Should -Throw '*Batch request failed*'
        }
    }
}
