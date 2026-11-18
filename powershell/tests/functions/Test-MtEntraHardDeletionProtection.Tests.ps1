Describe 'Test-MtEntraHardDeletionProtection' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtEntraHardDeletionProtection

        $script:UserId = '11111111-1111-1111-1111-111111111111'
        $script:GroupId = '22222222-2222-2222-2222-222222222222'
        $script:UserRow = "User \| $($script:UserId) \|"
        $script:GroupRow = "Group \| $($script:GroupId) \|"

        function Get-Entry {
            param($Type, $Id)
            [pscustomobject]@{ Type = $Type; Id = $Id }
        }

        function Get-GraphObject {
            param($Id, $Name, $Protected = $null)
            [pscustomobject]@{
                id = $Id; displayName = $Name; isHardDeleteProtectionEnabled = $Protected
            }
        }

        function Get-InventoryObject {
            param($Id, $Name)
            [pscustomobject]@{ id = $Id; displayName = $Name }
        }

        function Get-DeletedObject {
            param($Id, $Name, $ODataType)
            [pscustomobject]@{ id = $Id; displayName = $Name; '@odata.type' = $ODataType }
        }

        function Invoke-Check {
            Test-MtEntraHardDeletionProtection -HardDeletionProtectedObjects $State.Listed
        }
    }

    BeforeEach {
        $State = @{
            Detail = $null; Investigate = $false; Listed = @(); Protected = @{}
            ObjectById = @{}; DeletedById = @{}; Sequence = @{}; Seen = @{}; Wrap = $false
        }
        # The exception Invoke-MtGraphRequest lets through for a request Graph answers with 404.
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
            $notFound = $NotFoundError
            if ($State.Wrap) {
                $notFound = [System.InvalidOperationException]::new(
                    'Request failed.', $NotFoundError
                )
            }
            $id = $RelativeUri.Split('/')[-1]
            if ($RelativeUri -match '^directory/deletedItems/[0-9a-fA-F-]{36}$') {
                if ($null -eq $State.DeletedById[$id]) { throw $notFound }
                return $State.DeletedById[$id]
            }
            if ($RelativeUri -match '^(users|groups|applications|servicePrincipals)/[^/]+$') {
                if ($State.Sequence.ContainsKey($id)) {
                    $step = [int]$State.Seen[$id]
                    $State.Seen[$id] = $step + 1
                    $answers = $State.Sequence[$id]
                    return $answers[[Math]::Min($step, $answers.Count - 1)]
                }
                if ($null -eq $State.ObjectById[$id]) { throw $notFound }
                return $State.ObjectById[$id]
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
            Invoke-Check | Should -BeNullOrEmpty
            $State.Investigate | Should -BeTrue
            $State.Detail | Should -Match 'verified manually'
            $State.Detail | Should -Match 'The scan did not find any objects with Hard Deletion'
        }

        It 'is Investigate and lists the protected objects it finds' {
            $State.Protected['users'] = @(Get-InventoryObject $script:UserId 'Admin One')
            $State.Protected['directory/deletedItems/microsoft.graph.group'] = @(
                Get-InventoryObject $script:GroupId 'Deleted group'
            )

            Invoke-Check | Should -BeNullOrEmpty
            $State.Investigate | Should -BeTrue
            $State.Detail | Should -Match '2 object\(s\) have Hard Deletion Protection'
            $State.Detail | Should -Match "$($script:UserRow) Admin One \| Active"
            $State.Detail | Should -Match "$($script:GroupRow) Deleted group \| Soft deleted"
        }

        It 'counts an object once when it shows up as both active and soft deleted' {
            $State.Protected['users'] = @(Get-InventoryObject $script:UserId 'Admin One')
            $State.Protected['directory/deletedItems/microsoft.graph.user'] = @(
                Get-InventoryObject $script:UserId 'Admin One'
            )

            Invoke-Check | Should -BeNullOrEmpty
            $State.Detail | Should -Match '1 object\(s\) have Hard Deletion Protection'
            $State.Detail | Should -Match 'Admin One \| Active or soft deleted'
        }
    }

    Context 'Objects are listed' {
        It 'passes when every listed object is protected and nothing else is' {
            $State.Listed = @(Get-Entry User $script:UserId)
            $State.ObjectById[$script:UserId] =
                Get-GraphObject $script:UserId 'Admin One' -Protected $true
            $State.Protected['users'] = @(Get-InventoryObject $script:UserId 'Admin One')

            Invoke-Check | Should -BeTrue
            $State.Investigate | Should -BeFalse
            $State.Detail | Should -Match 'Well done'
        }

        It 'is Investigate when listed objects pass but other protected objects are not listed' {
            $State.Listed = @(Get-Entry User $script:UserId)
            $State.ObjectById[$script:UserId] =
                Get-GraphObject $script:UserId 'Admin One' -Protected $true
            $State.Protected['users'] = @(
                Get-InventoryObject $script:UserId 'Admin One'
                Get-InventoryObject $script:GroupId 'Other admin'
            )

            Invoke-Check | Should -BeNullOrEmpty
            $State.Investigate | Should -BeTrue
            $State.Detail | Should -Match 'Other admin'
            $State.Detail | Should -Not -Match 'Admin One \|'
        }

        It 'fails and lists an unprotected object, even when others are not listed' {
            $State.Listed = @(Get-Entry user $script:UserId)
            $State.ObjectById[$script:UserId] = Get-GraphObject $script:UserId 'Plain | User'
            $State.Protected['groups'] = @(Get-InventoryObject $script:GroupId 'Some group')

            Invoke-Check | Should -BeFalse
            $State.Investigate | Should -BeFalse
            $State.Detail | Should -Match '1 of 1 listed object'
            $State.Detail | Should -Match "$($script:UserRow) Plain \\\| User \| Not protected"
            $State.Detail | Should -Match 'Some group'
        }

        It 'fails an object that cannot be found' {
            $State.Listed = @(Get-Entry Group $script:GroupId)

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match 'Not found'
        }

        It 'fails a listed object that is protected but soft deleted' {
            $State.Listed = @(Get-Entry Group $script:GroupId)
            $State.DeletedById[$script:GroupId] =
                Get-DeletedObject $script:GroupId 'Deleted group' `
                    -ODataType '#microsoft.graph.group'
            $State.Protected['directory/deletedItems/microsoft.graph.group'] = @(
                Get-InventoryObject $script:GroupId 'Deleted group'
            )

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match "$($script:GroupRow) Deleted group \| Soft deleted"
        }

        It 'reports a listed object soft deleted without protection as soft deleted' {
            $State.Listed = @(Get-Entry User $script:UserId)
            $State.DeletedById[$script:UserId] =
                Get-DeletedObject $script:UserId 'Removed user' `
                    -ODataType '#microsoft.graph.user'

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match "$($script:UserRow) Removed user \| Soft deleted"
            $State.Detail | Should -Not -Match 'Not found'
        }

        It 'reads a deleted object through the documented deletedItems route, once' {
            $State.Listed = @(Get-Entry Group $script:GroupId)

            Invoke-Check | Should -BeFalse
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 1 -Exactly `
                -ParameterFilter {
                    $RelativeUri -eq 'directory/deletedItems/22222222-2222-2222-2222-222222222222'
                }
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 0 -Exactly `
                -ParameterFilter {
                    $RelativeUri -like 'directory/deletedItems/microsoft.graph.*/22222222-*'
                }
        }

        It 'reports a deleted object of another type as not found' {
            $State.Listed = @(Get-Entry Group $script:UserId)
            $State.DeletedById[$script:UserId] =
                Get-DeletedObject $script:UserId 'Removed user' `
                    -ODataType '#microsoft.graph.user'

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match "Group \| $($script:UserId) \|  \| Not found"
            $State.Detail | Should -Not -Match 'Soft deleted'
        }

        It 'reports a deleted object without an @odata.type as not found' {
            $State.Listed = @(Get-Entry User $script:UserId)
            $State.DeletedById[$script:UserId] = Get-InventoryObject $script:UserId 'Removed user'

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match "$($script:UserRow)  \| Not found"
            $State.Detail | Should -Not -Match 'Soft deleted'
        }

        It 'shows a display name that looks like a link or an image as plain text' {
            $State.Listed = @(Get-Entry User $script:UserId; Get-Entry Group $script:GroupId)
            $State.ObjectById[$script:UserId] =
                Get-GraphObject $script:UserId '[Sign in](https://phish.example)'
            $State.ObjectById[$script:GroupId] =
                Get-GraphObject $script:GroupId '![x](https://attacker.example/p.png)'

            Invoke-Check | Should -BeFalse
            $State.Detail.Contains('\[Sign in\]\(https\://phish.example\)') | Should -BeTrue
            $State.Detail.Contains('\!\[x\]\(https\://attacker.example/p.png\)') | Should -BeTrue
            $State.Detail.Contains('[Sign in](') | Should -BeFalse
            $State.Detail.Contains('![x](') | Should -BeFalse
        }

        It 'reports a 404 that sits on the inner exception as not found' {
            $State.Listed = @(Get-Entry Group $script:GroupId)
            $State.Wrap = $true

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match "$($script:GroupRow)  \| Not found"
        }

        It 'rejects an Id that is not a GUID without calling Graph' {
            InModuleScope Maester {
                $Entry = [pscustomobject]@{ Type = 'User'; Id = 'admin@contoso.com' }
                { Get-MtEntraHardDeletionObjectStatus -Configured $Entry } |
                    Should -Throw '*Id must be the object ID (a GUID)*'
            }
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 0 -Exactly
        }

        It 'fails the check with an error that names the entry when an Id is not a GUID' {
            $State.Listed = @(Get-Entry User 'admin@contoso.com')

            { Invoke-Check } | Should -Throw "*Id 'admin@contoso.com'*"
        }

        It 'keeps a display name with line breaks in one table cell' {
            $State.Listed = @(Get-Entry User $script:UserId)
            $State.ObjectById[$script:UserId] =
                Get-GraphObject $script:UserId "Ops`r`nTeam`nLead"

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match "$($script:UserRow) Ops Team Lead \| Not protected"
        }

        It 'counts an entry that is listed more than once as one object' {
            $HexId = 'aabbccdd-1111-2222-3333-eeeeffff0000'
            $State.Listed = @(
                Get-Entry User $HexId
                Get-Entry user $HexId.ToUpperInvariant()
                Get-Entry User "{$HexId}"
                Get-Entry Group $script:GroupId
            )
            $State.ObjectById[$HexId] = Get-GraphObject $HexId 'Plain user'

            $HexId | Should -Not -BeExactly $HexId.ToUpperInvariant()
            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match '2 of 2 listed object\(s\)'
            [regex]::Matches($State.Detail, "\| User \| $HexId \|").Count | Should -Be 1
            $State.Detail | Should -Match "$($script:GroupRow)  \| Not found"
        }

        It 'keeps one passing row when an entry is listed twice and both lookups pass' {
            $State.Listed = @(Get-Entry User $script:UserId; Get-Entry User "{$script:UserId}")
            $State.ObjectById[$script:UserId] =
                Get-GraphObject $script:UserId 'Admin One' -Protected $true
            $State.Protected['users'] = @(Get-InventoryObject $script:UserId 'Admin One')

            Invoke-Check | Should -BeTrue
            $State.Detail | Should -Match 'All 1 listed object\(s\)'
        }

        It 'lets a failing lookup win when an entry is listed twice and the lookups differ' {
            $State.Listed = @(Get-Entry User $script:UserId; Get-Entry User "{$script:UserId}")
            $State.Sequence[$script:UserId] = @(
                Get-GraphObject $script:UserId 'Admin One' -Protected $true
                Get-GraphObject $script:UserId 'Admin One' -Protected $null
            )

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match '1 of 1 listed object'
            $State.Detail | Should -Match "$($script:UserRow) Admin One \| Not protected"
        }

        It 'keeps the failure when the failing lookup comes first' {
            $State.Listed = @(Get-Entry User $script:UserId; Get-Entry User "{$script:UserId}")
            $State.Sequence[$script:UserId] = @(
                Get-GraphObject $script:UserId 'Admin One' -Protected $null
                Get-GraphObject $script:UserId 'Admin One' -Protected $true
            )

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match "$($script:UserRow) Admin One \| Not protected"
        }

        It 'uses the canonical lower-case form of the Id in the request and in the result' {
            $State.Listed = @(Get-Entry User '{AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB}')
            $State.ObjectById['aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb'] =
                Get-GraphObject 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb' 'Mixed case'

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -MatchExactly (
                'User \| aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb \| Mixed case \| Not protected'
            )
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 1 -Exactly `
                -ParameterFilter { $RelativeUri -ceq 'users/aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb' }
        }

        It 'keeps a protected object in the unlisted table when listed under another Type' {
            $State.Listed = @(Get-Entry Group $script:UserId)
            $State.Protected['users'] = @(Get-InventoryObject $script:UserId 'Admin One')

            Invoke-Check | Should -BeFalse
            $State.Detail | Should -Match "Group \| $($script:UserId) \|  \| Not found"
            $State.Detail | Should -Match "$($script:UserRow) Admin One \| Active"
        }

        It 'does not list a correctly listed object as unlisted' {
            $State.Listed = @(Get-Entry User $script:UserId)
            $State.ObjectById[$script:UserId] =
                Get-GraphObject $script:UserId 'Admin One' -Protected $true
            $State.Protected['users'] = @(Get-InventoryObject $script:UserId 'Admin One')

            Invoke-Check | Should -BeTrue
            $State.Detail | Should -Not -Match 'other object'
        }

        It 'shows the first 25 unlisted objects and the total' {
            $State.Listed = @(Get-Entry User $script:UserId)
            $State.ObjectById[$script:UserId] =
                Get-GraphObject $script:UserId 'Admin One' -Protected $true
            $State.Protected['groups'] = @(
                1..30 | ForEach-Object {
                    Get-InventoryObject ('33333333-3333-3333-3333-{0:D12}' -f $_) "Group $_"
                }
            )

            Invoke-Check | Should -BeNullOrEmpty
            $State.Detail | Should -Match '30 other object\(s\)'
            $State.Detail | Should -Match 'Showing the first 25 of 30 objects'
            $State.Detail | Should -Match 'Group 25 \|'
            $State.Detail | Should -Not -Match 'Group 26 \|'
        }
    }

    Context 'Errors' {
        It 'throws for an invalid object type' {
            $State.Listed = @(Get-Entry Device $script:UserId)

            { Invoke-Check } |
                Should -Throw '*Type must be User, Group, Application or ServicePrincipal*'
        }

        It 'throws for a Graph error that is not a 404' {
            $State.Listed = @(Get-Entry User $script:UserId)
            Mock -ModuleName Maester Invoke-MtGraphRequest -MockWith {
                param($RelativeUri)
                if ($RelativeUri -like 'users/*') {
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new(
                        'Response status code does not indicate success: Forbidden (Forbidden).',
                        [System.Net.Http.HttpResponseMessage]::new(
                            [System.Net.HttpStatusCode]::Forbidden
                        )
                    )
                }
                return @()
            }

            { Invoke-Check } | Should -Throw '*Forbidden*'
        }

        It 'throws, instead of reporting Not found, when the error has no HTTP response' {
            $State.Listed = @(Get-Entry User $script:UserId)
            Mock -ModuleName Maester Invoke-MtGraphRequest -MockWith {
                param($RelativeUri)
                if ($RelativeUri -like 'users/*') {
                    throw [System.InvalidOperationException]::new('Batch request failed.')
                }
                return @()
            }

            { Invoke-Check } | Should -Throw '*Batch request failed*'
        }
    }
}
