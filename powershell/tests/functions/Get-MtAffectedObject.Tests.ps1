BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Affected objects' {
    Context 'ConvertTo-MtAffectedObjectRecord' {
        It 'Should use a UPN as the object label when no display name is available' {
            $affectedObject = InModuleScope Maester {
                ConvertTo-MtAffectedObjectRecord -GraphObjectType Users -GraphObjects ([PSCustomObject]@{
                        id                = '11111111-1111-1111-1111-111111111111'
                        userPrincipalName = 'user@contoso.com'
                    })
            }

            $affectedObject.DisplayName | Should -Be 'user@contoso.com'
            $affectedObject.Type | Should -Be 'User'
            $affectedObject.AnchorKind | Should -Be 'Instance'
            $affectedObject.Source | Should -Be 'GraphObjects'
        }

        It 'Should infer the type from @odata.type when no type is declared' {
            $affectedObject = InModuleScope Maester {
                ConvertTo-MtAffectedObjectRecord -GraphObjects ([PSCustomObject]@{
                        '@odata.type' = '#microsoft.graph.group'
                        id            = '22222222-2222-2222-2222-222222222222'
                        displayName   = 'Sales'
                    })
            }

            $affectedObject.Type | Should -Be 'Group'
            $affectedObject.PortalLink | Should -BeLike '*groupId/22222222-2222-2222-2222-222222222222*'
        }

        It 'Should mark tenant level settings types as a surface' {
            $affectedObject = InModuleScope Maester {
                ConvertTo-MtAffectedObjectRecord -GraphObjectType AuthorizationPolicy -GraphObjects ([PSCustomObject]@{
                        displayName = 'Authorization Policy'
                    })
            }

            $affectedObject.AnchorKind | Should -Be 'Surface'
        }

        It 'Should not drop objects of an unknown type' {
            $affectedObject = InModuleScope Maester {
                ConvertTo-MtAffectedObjectRecord -GraphObjects ([PSCustomObject]@{
                        '@odata.type' = '#microsoft.graph.someNewThing'
                        id            = '33333333-3333-3333-3333-333333333333'
                    })
            }

            $affectedObject | Should -Not -BeNullOrEmpty
            $affectedObject.Type | Should -Be '#microsoft.graph.someNewThing'
        }

        It 'Should not treat an object of an instance type without id as an addressable instance' {
            $affectedObject = InModuleScope Maester {
                ConvertTo-MtAffectedObjectRecord -GraphObjectType Users -GraphObjects ([PSCustomObject]@{
                        displayName = 'Jane Doe'
                    })
            }

            $affectedObject.AnchorKind | Should -Be 'Unknown'
            $affectedObject.PortalLink | Should -BeNullOrEmpty
        }

        It 'Should keep the settings page link of a surface type without id' {
            $affectedObject = InModuleScope Maester {
                ConvertTo-MtAffectedObjectRecord -GraphObjectType AuthorizationPolicy -GraphObjects ([PSCustomObject]@{
                        displayName = 'Authorization Policy'
                    })
            }

            $affectedObject.PortalLink | Should -BeLike '*UserSettings*'
        }

        It 'Should keep the user principal name on user records' {
            $affectedObject = InModuleScope Maester {
                ConvertTo-MtAffectedObjectRecord -GraphObjectType Users -GraphObjects ([PSCustomObject]@{
                        id                = '11111111-1111-1111-1111-111111111111'
                        displayName       = 'Jane Doe'
                        userPrincipalName = 'jane@contoso.com'
                    })
            }

            $affectedObject.DisplayName | Should -Be 'Jane Doe'
            $affectedObject.UserPrincipalName | Should -Be 'jane@contoso.com'
        }

        It 'Should map <OdataType> to the catalog type <Expected>' -ForEach @(
            @{ OdataType = '#microsoft.graph.servicePrincipal'; Expected = 'ServicePrincipal' }
            @{ OdataType = '#microsoft.graph.directoryRole'; Expected = 'DirectoryRole' }
            @{ OdataType = '#microsoft.graph.conditionalAccessPolicy'; Expected = 'ConditionalAccessPolicy' }
        ) {
            $result = InModuleScope Maester -Parameters @{ OdataType = $OdataType } {
                param($OdataType)
                $record = ConvertTo-MtAffectedObjectRecord -GraphObjects ([PSCustomObject]@{
                        '@odata.type' = $OdataType
                        id            = '33333333-3333-3333-3333-333333333333'
                    })
                $kept = Select-MtAffectedObjectByType -Objects @($record) -WarningVariable warnings -WarningAction SilentlyContinue
                [PSCustomObject]@{ Record = $record; Kept = @($kept).Count; Warnings = @($warnings).Count }
            }

            $result.Record.Type | Should -Be $Expected
            $result.Record.AnchorKind | Should -Be 'Instance'
            $result.Kept | Should -Be 1
            $result.Warnings | Should -Be 0
        }

        It 'Should give a <GraphObjectType> record its canonical type and portal link' -ForEach @(
            @{ GraphObjectType = 'ServicePrincipals'; Expected = 'ServicePrincipal'; Blade = 'ManagedAppMenuBlade/~/Overview/objectId/' }
            @{ GraphObjectType = 'AccessPackages'; Expected = 'AccessPackage'; Blade = 'EntitlementMenuBlade/~/overview/entitlementId/' }
            @{ GraphObjectType = 'AccessPackageCatalogs'; Expected = 'AccessPackageCatalog'; Blade = 'CatalogBlade/catalogId/' }
        ) {
            $record = InModuleScope Maester -Parameters @{ GraphObjectType = $GraphObjectType } {
                param($GraphObjectType)
                ConvertTo-MtAffectedObjectRecord -GraphObjectType $GraphObjectType -GraphObjects ([PSCustomObject]@{
                        id          = '44444444-4444-4444-4444-444444444444'
                        displayName = 'Payroll'
                    })
            }

            $record.Type | Should -Be $Expected
            $record.AnchorKind | Should -Be 'Instance'
            $record.PortalLink | Should -BeLike "*$($Blade)44444444-4444-4444-4444-444444444444"
        }
    }

    Context 'Get-MtAffectedObjectFromMarkdown' {
        It 'Should extract a conditional access policy and its display name' {
            $markdown = '| [Require MFA](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/44444444-4444-4444-4444-444444444444) |'

            $affectedObject = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown -TestId 'MT.1001'
            }

            $affectedObject.Type | Should -Be 'ConditionalAccessPolicy'
            $affectedObject.Id | Should -Be '44444444-4444-4444-4444-444444444444'
            $affectedObject.DisplayName | Should -Be 'Require MFA'
            $affectedObject.TestId | Should -Be 'MT.1001'
        }

        It 'Should keep the matched url as the portal link' {
            $markdown = '| [Require MFA](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/44444444-4444-4444-4444-444444444444) |'

            $affectedObject = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown
            }

            $affectedObject.PortalLink | Should -Be 'https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/44444444-4444-4444-4444-444444444444'
        }

        It 'Should attribute a url to its most specific pattern only' {
            # The service principal url also satisfies the less specific app registration pattern.
            $markdown = '[Contoso App](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/44444444-4444-4444-4444-444444444444/appId/55555555-5555-5555-5555-555555555555)'

            $objects = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown
            }

            @($objects).Count | Should -Be 1
            $objects.Type | Should -Be 'ServicePrincipal'
            $objects.Id | Should -Be '44444444-4444-4444-4444-444444444444'
        }

        It 'Should capture the display name of a link that has a title' {
            $markdown = '| [Microsoft Graph Command Line Tools](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Properties/objectId/55555555-5555-5555-5555-555555555555/appId/66666666-6666-6666-6666-666666666666 "Backs Connect-MgGraph") |'

            $affectedObject = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown
            }

            $affectedObject.Type | Should -Be 'ServicePrincipal'
            $affectedObject.Id | Should -Be '55555555-5555-5555-5555-555555555555'
            $affectedObject.DisplayName | Should -Be 'Microsoft Graph Command Line Tools'
            $affectedObject.PortalLink | Should -Not -BeLike '* *'
        }

        It 'Should capture a display name that contains brackets' {
            $markdown = '- [[RaviK] - Require app protection policy](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/44444444-4444-4444-4444-444444444444)'

            $affectedObject = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown
            }

            $affectedObject.DisplayName | Should -Be '[RaviK] - Require app protection policy'
        }

        It 'Should remove markdown escapes from the display name' {
            $markdown = '- [AzMfa Test \(Require MFA\) test\_21783](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/44444444-4444-4444-4444-444444444444)'

            $affectedObject = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown
            }

            $affectedObject.DisplayName | Should -Be 'AzMfa Test (Require MFA) test_21783'
        }

        It 'Should capture an enterprise application linked by object id only' {
            $markdown = '- [Mailbox Migration Account](https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/55555555-5555-5555-5555-555555555555) with Global Administrator'

            $affectedObject = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown
            }

            $affectedObject.Type | Should -Be 'ServicePrincipal'
            $affectedObject.Id | Should -Be '55555555-5555-5555-5555-555555555555'
            $affectedObject.DisplayName | Should -Be 'Mailbox Migration Account'
        }

        It 'Should capture the catalog of an access drift link' {
            $markdown = '| 📚 [Contoso Catalog \| \(Sales\)](https://entra.microsoft.com/#view/Microsoft_Azure_ELMAdmin/ReconReviewAccessDriftBlade.ReactView/summaryId/v1_0000/resourceId/aaaaaaaa-1111-2222-3333-444444444444/catalogIdentifier/bbbbbbbb-1111-2222-3333-444444444444/catalogName/Contoso%20Catalog%20%7C%20%28Sales%29/resourceType/group/resourceName/Sales%20Team/driftTotal~/4/driftUnauthorized~/4/driftMissing~/0 "View access drift") |'

            $affectedObject = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown -TestId 'MT.1255'
            }

            @($affectedObject).Count | Should -Be 1
            $affectedObject.Type | Should -Be 'AccessPackageCatalogDrift'
            $affectedObject.Id | Should -Be 'bbbbbbbb-1111-2222-3333-444444444444'
            $affectedObject.DisplayName | Should -Be 'Contoso Catalog | (Sales)'
        }

        It 'Should capture users listed as empty links by their UPN' {
            $markdown = "| ❌ Fail | [jane@contoso.com]() | 07/14/2026 |`n| ❌ Fail | [not a user]() | 07/14/2026 |"

            $affectedObject = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown -TestId 'MT.1024'
            }

            @($affectedObject).Count | Should -Be 1
            $affectedObject.Type | Should -Be 'User'
            $affectedObject.Id | Should -Be 'jane@contoso.com'
            $affectedObject.UserPrincipalName | Should -Be 'jane@contoso.com'
        }

        It 'Should return nothing for markdown without portal links' {
            $affectedObject = InModuleScope Maester {
                Get-MtAffectedObjectFromMarkdown -Markdown 'All good, nothing to report.'
            }

            @($affectedObject).Count | Should -Be 0
        }

        It 'Should return nothing for empty markdown' {
            $affectedObject = InModuleScope Maester {
                Get-MtAffectedObjectFromMarkdown -Markdown ''
            }

            @($affectedObject).Count | Should -Be 0
        }

        It 'Should not take a non-https url from a crafted link as the portal link' {
            # A display name such as this one closes the link early and injects its own url.
            $markdown = '  - [x](javascript:alert`1`//Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/44444444-4444-4444-4444-444444444444) [y](#)'

            $objects = InModuleScope Maester -Parameters @{ Markdown = $markdown } {
                param($Markdown)
                Get-MtAffectedObjectFromMarkdown -Markdown $Markdown
            }

            @($objects | Where-Object { $_.PortalLink -notlike 'https://*' }).Count | Should -Be 0
        }
    }

    Context 'Get-MtAffectedObjectFromCache' {
        It 'Should classify graph cache keys by their url shape' {
            $objects = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/v1.0/users/55555555-5555-5555-5555-555555555555/authentication/methods' = 'x'
                    'https://graph.microsoft.com/beta/policies/authorizationPolicy'                                      = 'x'
                    'https://graph.microsoft.com/v1.0/servicePrincipals?$select=id'                                      = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            # A keyed read of a directory collection normalizes onto the object it addresses
            ($objects | Where-Object { $_.Type -eq 'User' }).AnchorKind | Should -Be 'Instance'
            ($objects | Where-Object { $_.Type -eq 'User' }).Id | Should -Be '55555555-5555-5555-5555-555555555555'
            ($objects | Where-Object { $_.Type -eq 'policies/authorizationPolicy' }).AnchorKind | Should -Be 'Singleton'
            ($objects | Where-Object { $_.Type -eq 'servicePrincipals' }).AnchorKind | Should -Be 'Collection'
        }

        It 'Should read the url from a key that carries an output type suffix' {
            $objects = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/beta/security/identities/healthIssues_[Hashtable]'                    = 'x'
                    'https://graph.microsoft.com/beta/directory/recommendations?$expand=impactedResources_[Hashtable]' = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            $objects.Type | Should -Contain 'security/identities/healthIssues'
            $objects.Type | Should -Contain 'directory/recommendations'
            $objects.Type | Where-Object { $_ -like '*Hashtable*' } | Should -BeNullOrEmpty
        }

        It 'Should normalize a keyed directory read onto its canonical Entra type' {
            $objects = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/v1.0/users/55555555-5555-5555-5555-555555555555'                       = 'x'
                    'https://graph.microsoft.com/v1.0/users/55555555-5555-5555-5555-555555555555/authentication/methods' = 'x'
                    'https://graph.microsoft.com/v1.0/groups/77777777-7777-7777-7777-777777777777/members'              = 'x'
                    'https://graph.microsoft.com/v1.0/servicePrincipals/88888888-8888-8888-8888-888888888888'           = 'x'
                    'https://graph.microsoft.com/v1.0/directoryRoles/99999999-9999-9999-9999-999999999999/members'      = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            # The user is one object, not one per sub-resource that was read
            @($objects | Where-Object { $_.Type -eq 'User' }).Count | Should -Be 1
            ($objects | Where-Object { $_.Type -eq 'User' }).System | Should -Be 'EntraID'
            ($objects | Where-Object { $_.Type -eq 'User' }).Id | Should -Be '55555555-5555-5555-5555-555555555555'
            ($objects | Where-Object { $_.Type -eq 'Group' }).Id | Should -Be '77777777-7777-7777-7777-777777777777'
            ($objects | Where-Object { $_.Type -eq 'ServicePrincipal' }).AnchorKind | Should -Be 'Instance'
            # The sub-resource must not leak into the type name as directoryRoles/members
            ($objects | Where-Object { $_.Type -eq 'DirectoryRole' }).Id | Should -Be '99999999-9999-9999-9999-999999999999'
        }

        It 'Should treat a UPN key as a user rather than folding it into the type' {
            $affectedObject = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/v1.0/users/alice@contoso.com?$select=id' = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            $affectedObject.System | Should -Be 'EntraID'
            $affectedObject.Type | Should -Be 'User'
            $affectedObject.Id | Should -Be 'alice@contoso.com'
            $affectedObject.AnchorKind | Should -Be 'Instance'
        }

        It 'Should keep a guest UPN whole and decode it' {
            $affectedObject = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/v1.0/users/john_contoso.com%23EXT%23@tenant.onmicrosoft.com' = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            $affectedObject.System | Should -Be 'EntraID'
            $affectedObject.Type | Should -Be 'User'
            $affectedObject.Id | Should -Be 'john_contoso.com#EXT#@tenant.onmicrosoft.com'
            $affectedObject.UserPrincipalName | Should -Be 'john_contoso.com#EXT#@tenant.onmicrosoft.com'
        }

        It 'Should strip an empty POST body suffix from the cache key' {
            $affectedObject = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/beta/policies/authorizationPolicy_' = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            $affectedObject.Type | Should -Be 'policies/authorizationPolicy'
            $affectedObject.AnchorKind | Should -Be 'Singleton'
        }

        It 'Should map an appId alternate key onto the app registration' {
            $affectedObject = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    "https://graph.microsoft.com/beta/applications(appId='66666666-6666-6666-6666-666666666666')" = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            # App registrations are keyed by appId, the same id their portal links carry.
            $affectedObject.System | Should -Be 'EntraID'
            $affectedObject.Type | Should -Be 'AppRegistration'
            $affectedObject.Id | Should -Be '66666666-6666-6666-6666-666666666666'
            $affectedObject.AnchorKind | Should -Be 'Instance'
        }

        It 'Should map a keyed read below <Path> onto <Expected>' -ForEach @(
            @{ Path = 'identityGovernance/entitlementManagement/accessPackages/77777777-7777-7777-7777-777777777777/accessPackageResourceRoleScopes'; Expected = 'AccessPackage' }
            @{ Path = 'identityGovernance/entitlementManagement/accessPackageCatalogs/77777777-7777-7777-7777-777777777777/accessPackageResources'; Expected = 'AccessPackageCatalog' }
        ) {
            $affectedObject = InModuleScope Maester -Parameters @{ Path = $Path } {
                param($Path)
                $__MtSession.GraphCache = @{ "https://graph.microsoft.com/beta/$Path" = 'x' }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            $affectedObject.System | Should -Be 'EntraID'
            $affectedObject.Type | Should -Be $Expected
            $affectedObject.Id | Should -Be '77777777-7777-7777-7777-777777777777'
        }

        It 'Should leave an applications read keyed by object id as a Graph path' {
            # Object ids and the appIds that key app registrations are different values, so these cannot merge.
            $affectedObject = InModuleScope Maester {
                $__MtSession.GraphCache = @{ 'https://graph.microsoft.com/beta/applications/66666666-6666-6666-6666-666666666666' = 'x' }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            $affectedObject.Type | Should -Be 'applications'
        }

        It 'Should leave collections that are not keyed directory reads alone' {
            $objects = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/v1.0/users?$select=id'                     = 'x'
                    'https://graph.microsoft.com/v1.0/applications/99999999-9999-9999-9999-999999999999' = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            ($objects | Where-Object { $_.Type -eq 'users' }).AnchorKind | Should -Be 'Collection'
            # applications is excluded from the mapping: the cache keys by object id, portal links by app id
            ($objects | Where-Object { $_.Type -eq 'applications' }).System | Should -Be 'MicrosoftGraph'
        }

        It 'Should merge a cache read with the check that rendered the same object' {
            $inventory = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/beta/groups/44444444-4444-4444-4444-444444444444' = 'x'
                }
                try {
                    Get-MtAffectedObject -MaesterResults ([PSCustomObject]@{
                            Tests = @([PSCustomObject]@{
                                    Id           = 'MT.1044'
                                    ResultDetail = [PSCustomObject]@{
                                        TestResult     = '[Admins](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/44444444-4444-4444-4444-444444444444)'
                                        RelatedObjects = @()
                                    }
                                })
                        })
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            @($inventory).Count | Should -Be 1
            $inventory.Type | Should -Be 'Group'
            $inventory.DisplayName | Should -Be 'Admins'
            $inventory.Tests | Should -Be @('MT.1044')
            $inventory.Sources | Should -Contain 'Markdown'
            $inventory.Sources | Should -Contain 'GraphCache'
        }

        It 'Should redact a user that only the request cache saw' {
            $leaked = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/v1.0/users/alice@contoso.com' = 'x'
                }
                try {
                    $inventory = @(Get-MtAffectedObject -MaesterResults ([PSCustomObject]@{ Tests = @() }))
                    $results = [PSCustomObject]@{ AffectedObjects = $inventory }
                    $map = Get-MtUserIdentityReplacementMap -MaesterResults $results
                    $json = $results | ConvertTo-Json -Depth 5 -Compress
                    (ConvertTo-MtRedactedReportContent -Content $json -ReplacementMap $map -JsonEncoded).Contains('alice@contoso.com')
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            $leaked | Should -BeFalse
        }

        It 'Should skip batch requests' {
            $objects = InModuleScope Maester {
                $__MtSession.GraphCache = @{ 'https://graph.microsoft.com/v1.0/$batch_{"requests":[]}' = 'x' }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            @($objects).Count | Should -Be 0
        }

        It 'Should skip action endpoints that address no resource' {
            $objects = InModuleScope Maester {
                $__MtSession.GraphCache = @{ 'https://graph.microsoft.com/v1.0/security/runHuntingQuery_{"Query":"x"}' = 'x' }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            @($objects).Count | Should -Be 0
        }

        It 'Should anchor a nested keyed path on the outermost object' {
            $affectedObject = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/v1.0/policies/22222222-2222-2222-2222-222222222222/assignments/33333333-3333-3333-3333-333333333333' = 'x'
                }
                try {
                    Get-MtAffectedObjectFromCache
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            $affectedObject.Id | Should -Be '22222222-2222-2222-2222-222222222222'
        }
    }

    Context 'Get-MtAffectedObject' {
        It 'Should merge a user known only by UPN into the user known by object id' {
            $inventory = InModuleScope Maester {
                $__MtSession.GraphCache = @{
                    'https://graph.microsoft.com/beta/users' = @{ value = @(@{ id = '88888888-8888-8888-8888-888888888888'; userPrincipalName = 'jane@contoso.com' }) }
                }
                try {
                    Get-MtAffectedObject -MaesterResults ([PSCustomObject]@{
                            Tests = @(
                                [PSCustomObject]@{
                                    Id           = 'MT.1024'
                                    ResultDetail = [PSCustomObject]@{ TestResult = '| [jane@contoso.com]() |'; RelatedObjects = @() }
                                }
                                [PSCustomObject]@{
                                    Id           = 'MT.1026'
                                    ResultDetail = [PSCustomObject]@{
                                        TestResult     = '[Jane Doe](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/88888888-8888-8888-8888-888888888888)'
                                        RelatedObjects = @()
                                    }
                                }
                            )
                        }) | Where-Object Type -EQ 'User'
                } finally {
                    $__MtSession.GraphCache = @{}
                }
            }

            @($inventory).Count | Should -Be 1
            $inventory.Id | Should -Be '88888888-8888-8888-8888-888888888888'
            $inventory.DisplayName | Should -Be 'Jane Doe'
            $inventory.UserPrincipalName | Should -Be 'jane@contoso.com'
            $inventory.Tests | Should -Be @('MT.1024', 'MT.1026')
        }

        It 'Should merge sources and aggregate the referencing tests' {
            $results = [PSCustomObject]@{
                Tests = @(
                    [PSCustomObject]@{
                        Id           = 'MT.1001'
                        ResultDetail = [PSCustomObject]@{
                            RelatedObjects = @(
                                [PSCustomObject]@{
                                    System = 'EntraID'; AnchorKind = 'Instance'; Type = 'ConditionalAccessPolicy'
                                    Id = '44444444-4444-4444-4444-444444444444'; DisplayName = 'Require MFA'
                                    PortalLink = 'https://entra.microsoft.com/policy'; Source = 'GraphObjects'
                                }
                            )
                            TestResult     = ''
                        }
                    },
                    [PSCustomObject]@{
                        Id           = 'MT.1002'
                        ResultDetail = [PSCustomObject]@{
                            RelatedObjects = @()
                            TestResult     = '[Require MFA](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/44444444-4444-4444-4444-444444444444)'
                        }
                    }
                )
            }

            $inventory = InModuleScope Maester -Parameters @{ Results = $results } {
                param($Results)
                Get-MtAffectedObject -MaesterResults $Results -ExcludeSessionCache
            }

            @($inventory).Count | Should -Be 1
            $inventory.Tests | Should -Be @('MT.1001', 'MT.1002')
            $inventory.Sources | Should -Contain 'GraphObjects'
            $inventory.Sources | Should -Contain 'Markdown'
            # The structured record outranks the markdown one for the portal link
            $inventory.PortalLink | Should -Be 'https://entra.microsoft.com/policy'
            $inventory.UniqueId | Should -BeLike 'object-*'
        }

        It 'Should produce a stable unique id for the same identity' {
            $ids = InModuleScope Maester {
                @(
                    (Get-MtAffectedObjectUniqueId -System 'EntraID' -Type 'User' -Id '11111111-1111-1111-1111-111111111111'),
                    (Get-MtAffectedObjectUniqueId -System 'EntraID' -Type 'User' -Id '11111111-1111-1111-1111-111111111111'),
                    (Get-MtAffectedObjectUniqueId -System 'EntraID' -Type 'User' -Id '99999999-9999-9999-9999-999999999999')
                )
            }

            $ids[0] | Should -Be $ids[1]
            $ids[0] | Should -Not -Be $ids[2]
        }

        It 'Should not let url casing change the unique id' {
            # Two cache reads of the same singleton that differ only in casing merge into one
            # record, and which casing survives depends on hashtable enumeration order.
            $ids = InModuleScope Maester {
                @(
                    (Get-MtAffectedObjectUniqueId -System 'MicrosoftGraph' -Type 'policies/authorizationPolicy' -Id $null),
                    (Get-MtAffectedObjectUniqueId -System 'MicrosoftGraph' -Type 'policies/authorizationpolicy' -Id $null)
                )
            }

            $ids[0] | Should -Be $ids[1]
        }
    }

    Context 'Facts' {
        BeforeAll {
            # One result that links a user, an agent identity, a blueprint, its principal and an Intune policy.
            $script:factResults = [PSCustomObject]@{
                Tests = @(
                    [PSCustomObject]@{
                        Id           = 'ZTA.1'
                        ResultDetail = [PSCustomObject]@{
                            TestResult = @(
                                '[Adele](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/aaaaaaaa-0000-0000-0000-000000000001)'
                                '[Agent](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AgentIdentity.MenuView/~/overview/objectId/aaaaaaaa-0000-0000-0000-000000000002/menuId/overview)'
                                '[Blueprint](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AgentBlueprintDetails.MenuView/~/overview/appId/aaaaaaaa-0000-0000-0000-000000000003)'
                                '[Blueprint](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AgentBlueprintDetails.MenuView/~/overview/objectId/aaaaaaaa-0000-0000-0000-000000000005)'
                                '[Policy](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/PolicySummaryBlade/policyId/aaaaaaaa-0000-0000-0000-000000000004/technology/mdm)'
                            ) -join "`n"
                        }
                    }
                )
            }

            # Runs the block with the session collecting affected objects and an empty fact store.
            function Invoke-WithFactCollection {
                param([scriptblock] $ScriptBlock)
                InModuleScope Maester -Parameters @{ Block = $ScriptBlock; Results = $script:factResults } {
                    param($Block, $Results)
                    $previous = $__MtSession.IncludeAffectedObjects
                    try {
                        $__MtSession.IncludeAffectedObjects = $true
                        $__MtSession.AffectedObjectFacts = $null
                        # Recreated here so the block runs in module scope, where the internal functions are.
                        & ([scriptblock]::Create($Block.ToString())) $Results
                    } finally {
                        $__MtSession.IncludeAffectedObjects = $previous
                        $__MtSession.AffectedObjectFacts = $null
                    }
                }
            }
        }

        It 'Should recognise agent identities, blueprints and Intune configuration policies in result links' {
            $inventory = Invoke-WithFactCollection { param($Results) Get-MtAffectedObject -MaesterResults $Results -ExcludeSessionCache }

            ($inventory | Where-Object Type -EQ 'AgentIdentity').Id | Should -Be 'aaaaaaaa-0000-0000-0000-000000000002'
            # By appId the link names the blueprint; by objectId, the blueprint's service principal.
            ($inventory | Where-Object Type -EQ 'AgentIdentityBlueprint').Id | Should -Be 'aaaaaaaa-0000-0000-0000-000000000003'
            ($inventory | Where-Object Type -EQ 'AgentIdentityBlueprintPrincipal').Id | Should -Be 'aaaaaaaa-0000-0000-0000-000000000005'
            $policy = $inventory | Where-Object Type -EQ 'ConfigurationPolicy'
            $policy.System | Should -Be 'Intune'
            $policy.Id | Should -Be 'aaaaaaaa-0000-0000-0000-000000000004'
        }

        It 'Should add facts to the object with the same System, Type and Id, and add no object of its own' {
            $inventory = Invoke-WithFactCollection {
                param($Results)
                Add-MtAffectedObjectFact -Type User -Id 'AAAAAAAA-0000-0000-0000-000000000001' -Source 'Test' -AsOf ([datetime]'2026-10-23T12:30:00Z') -Fact @(
                    @{ Name = 'MFA'; Value = 'Not registered'; Tone = 'Risk' }
                    @{ Name = 'Account'; Value = 'Member' }
                )
                Add-MtAffectedObjectFact -Type User -Id 'bbbbbbbb-0000-0000-0000-000000000009' -Source 'Test' -Fact @{ Name = 'Account'; Value = 'Guest' }
                Get-MtAffectedObject -MaesterResults $Results -ExcludeSessionCache
            }

            $user = $inventory | Where-Object Type -EQ 'User'
            $user.Facts.Name | Should -Be @('MFA', 'Account')
            $user.Facts[0].Tone | Should -Be 'Risk'
            $user.Facts[1].Tone | Should -Be 'Info'
            $user.Facts[0].Source | Should -Be 'Test'
            $user.Facts[0].AsOf | Should -Be '2026-10-23T12:30:00Z'
            $inventory.Id | Should -Not -Contain 'bbbbbbbb-0000-0000-0000-000000000009'
            ($inventory | Where-Object Type -EQ 'ConfigurationPolicy').Facts | Should -BeNullOrEmpty
        }

        It 'Should take facts from the pipeline, replace a fact with the same name and source, and treat an unknown tone as Info' {
            $inventory = Invoke-WithFactCollection {
                param($Results)
                @(
                    [PSCustomObject]@{ System = 'Intune'; Type = 'ConfigurationPolicy'; Id = 'aaaaaaaa-0000-0000-0000-000000000004'; Fact = @(@{ Name = 'Assignments'; Value = 'Not assigned'; Tone = 'Warning' }) }
                ) | Add-MtAffectedObjectFact -Source 'Test'
                Add-MtAffectedObjectFact -System Intune -Type ConfigurationPolicy -Id 'aaaaaaaa-0000-0000-0000-000000000004' -Source 'Test' -Fact @{ Name = 'Assignments'; Value = '2'; Tone = 'Loud' } -WarningAction SilentlyContinue
                Add-MtAffectedObjectFact -System Intune -Type ConfigurationPolicy -Id 'aaaaaaaa-0000-0000-0000-000000000004' -Source 'Other' -Fact @{ Name = 'Assignments'; Value = '3' }
                Get-MtAffectedObject -MaesterResults $Results -ExcludeSessionCache
            }

            $facts = ($inventory | Where-Object Type -EQ 'ConfigurationPolicy').Facts
            $facts.Count | Should -Be 2
            $facts[0].Value | Should -Be '2'
            $facts[0].Tone | Should -Be 'Info'
            $facts[1].Source | Should -Be 'Other'
        }

        It 'Should keep a fact''s Key and Raw value, a list as a list and a date as ISO text, and replace by Key' {
            $inventory = Invoke-WithFactCollection {
                param($Results)
                Add-MtAffectedObjectFact -Type User -Id 'aaaaaaaa-0000-0000-0000-000000000001' -Source 'Test' -Fact @(
                    @{ Name = 'MFA'; Value = 'Not registered'; Key = 'user.mfaRegistered'; Raw = $false }
                    @{ Name = 'Entra roles'; Value = 'Global Administrator (permanent)'; Key = 'user.privilegedRoles'; Raw = @('Global Administrator') }
                    @{ Name = 'Seen'; Value = 'Yesterday'; Key = 'contoso.lastSeen'; Raw = [datetime]'2026-10-22T08:00:00Z' }
                    @{ Name = 'Note'; Value = 'No key, so no raw'; Raw = 42 }
                )
                # Same key and source, new name: replaces the first fact.
                Add-MtAffectedObjectFact -Type User -Id 'aaaaaaaa-0000-0000-0000-000000000001' -Source 'Test' -Fact @{ Name = 'Multifactor'; Value = 'Registered'; Key = 'user.mfaRegistered'; Raw = $true }
                Add-MtAffectedObjectFact -Type User -Id 'aaaaaaaa-0000-0000-0000-000000000001' -Source 'Test' -Fact @{ Name = 'Bad'; Value = 'x'; Key = 'Not A Key'; Raw = 1 } -WarningAction SilentlyContinue
                Get-MtAffectedObject -MaesterResults $Results -ExcludeSessionCache
            }

            $facts = ($inventory | Where-Object Type -EQ 'User').Facts
            $mfa = @($facts | Where-Object Key -EQ 'user.mfaRegistered')
            $mfa.Count | Should -Be 1
            $mfa[0].Name | Should -Be 'Multifactor'
            $mfa[0].Raw | Should -BeTrue
            $roles = ($facts | Where-Object Key -EQ 'user.privilegedRoles').Raw
            , $roles | Should -BeOfType [string[]]
            $roles | Should -Be @('Global Administrator')
            ($facts | Where-Object Key -EQ 'contoso.lastSeen').Raw | Should -Be '2026-10-22T08:00:00Z'
            ($facts | Where-Object Name -EQ 'Note').Raw | Should -BeNullOrEmpty
            ($facts | Where-Object Name -EQ 'Bad').Key | Should -BeNullOrEmpty
        }

        It 'Should keep no facts when the run does not collect affected objects' {
            $kept = InModuleScope Maester {
                $previous = $__MtSession.IncludeAffectedObjects
                try {
                    $__MtSession.IncludeAffectedObjects = $false
                    $__MtSession.AffectedObjectFacts = $null
                    Add-MtAffectedObjectFact -Type User -Id 'aaaaaaaa-0000-0000-0000-000000000001' -Source 'Test' -Fact @{ Name = 'Account'; Value = 'Member' }
                    $__MtSession.AffectedObjectFacts
                } finally {
                    $__MtSession.IncludeAffectedObjects = $previous
                }
            }

            $kept | Should -BeNullOrEmpty
        }
    }

    Context 'IncludeAffectedObjects gating' {
        BeforeAll {
            $script:pesterResults = InModuleScope Maester {
                [PSCustomObject]@{
                    Tests             = @(
                        [PSCustomObject]@{
                            ExpandedName = 'MT.1001: Sample'
                            Result       = 'Passed'
                            ErrorRecord  = @()
                            ScriptBlock  = [scriptblock]::Create('$true | Should -BeTrue')
                            Duration     = [TimeSpan]::FromSeconds(1)
                            Block        = [PSCustomObject]@{ Tag = @('MT.1001'); Name = 'Maester'; Parent = $null }
                        }
                    )
                    Result            = 'Passed'
                    ExecutedAt        = [DateTime]::UtcNow
                    Duration          = [TimeSpan]::FromSeconds(1)
                    UserDuration      = [TimeSpan]::FromSeconds(1)
                    DiscoveryDuration = [TimeSpan]::Zero
                    FrameworkDuration = [TimeSpan]::Zero
                }
            }
        }

        It 'Should not attach the inventory by default' {
            $result = InModuleScope Maester -Parameters @{ PesterResults = $script:pesterResults } {
                param($PesterResults)
                ConvertTo-MtMaesterResult -PesterResults $PesterResults -SkipVersionCheck
            }

            $result.PSObject.Properties.Name | Should -Not -Contain 'AffectedObjects'
        }

        It 'Should attach the inventory when requested' {
            $result = InModuleScope Maester -Parameters @{ PesterResults = $script:pesterResults } {
                param($PesterResults)
                ConvertTo-MtMaesterResult -PesterResults $PesterResults -SkipVersionCheck -IncludeAffectedObjects
            }

            $result.PSObject.Properties.Name | Should -Contain 'AffectedObjects'
        }

        It 'Should only capture related objects when the session collects an inventory' {
            $captured = InModuleScope Maester {
                $graphObject = [PSCustomObject]@{
                    id          = '66666666-6666-6666-6666-666666666666'
                    displayName = 'Test User'
                }

                $previous = $__MtSession.IncludeAffectedObjects
                try {
                    $__MtSession.IncludeAffectedObjects = $false
                    Add-MtTestResultDetail -TestName 'ObjectGateOff' -Result 'ok' -Description 'd' `
                        -GraphObjects $graphObject -GraphObjectType Users
                    $off = $__MtSession.TestResultDetail['ObjectGateOff'].ContainsKey('RelatedObjects')

                    $__MtSession.IncludeAffectedObjects = $true
                    Add-MtTestResultDetail -TestName 'ObjectGateOn' -Result 'ok' -Description 'd' `
                        -GraphObjects $graphObject -GraphObjectType Users
                    $on = @($__MtSession.TestResultDetail['ObjectGateOn'].RelatedObjects)
                } finally {
                    $__MtSession.IncludeAffectedObjects = $previous
                    $__MtSession.TestResultDetail.Remove('ObjectGateOff')
                    $__MtSession.TestResultDetail.Remove('ObjectGateOn')
                }

                [PSCustomObject]@{ Off = $off; On = $on.Count; OnId = $on[0].Id }
            }

            # Without capture the property is absent, so results of runs that do not opt in are unchanged.
            $captured.Off | Should -BeFalse
            $captured.On | Should -Be 1
            $captured.OnId | Should -Be '66666666-6666-6666-6666-666666666666'
        }
    }

    Context 'PII redaction' {
        BeforeAll {
            $script:results = [PSCustomObject]@{
                AffectedObjects = @(
                    [PSCustomObject]@{
                        System = 'EntraID'; Type = 'User'; UniqueId = 'object-user-001'
                        Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'Jane Doe'
                    },
                    [PSCustomObject]@{
                        System = 'EntraID'; Type = 'Group'; UniqueId = 'object-group-001'
                        Id = '22222222-2222-2222-2222-222222222222'; DisplayName = 'Sales'
                    }
                )
            }
        }

        It 'Should map user display names and ids but leave other object types alone' {
            $map = InModuleScope Maester -Parameters @{ Results = $script:results } {
                param($Results)
                Get-MtUserIdentityReplacementMap -MaesterResults $Results
            }

            $map['Jane Doe'] | Should -Be 'object-user-001'
            $map['11111111-1111-1111-1111-111111111111'] | Should -Be 'object-user-001'
            $map.ContainsKey('Sales') | Should -BeFalse
        }

        It 'Should not map display names too short to match safely' {
            $map = InModuleScope Maester {
                Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{
                        AffectedObjects = @(
                            [PSCustomObject]@{
                                System = 'EntraID'; Type = 'User'; UniqueId = 'object-user-002'
                                Id = '33333333-3333-3333-3333-333333333333'; DisplayName = 'Ed'
                            }
                        )
                    })
            }

            $map.ContainsKey('Ed') | Should -BeFalse
            $map['33333333-3333-3333-3333-333333333333'] | Should -Be 'object-user-002'
        }

        It 'Should map the UPNs in the connection summary details' {
            $map = InModuleScope Maester {
                Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{
                        ConnectionSummary = @(
                            [PSCustomObject]@{ Service = 'Security & Compliance'; Status = 'Connected'; Details = "Using UPN 'exo.admin@contoso.com' from Exchange Online" }
                            [PSCustomObject]@{ Service = 'Microsoft Teams'; Status = 'Connected'; Details = 'a~b!c^d@contoso.com.' }
                            [PSCustomObject]@{ Service = 'SharePoint Online'; Status = 'Skipped'; Details = 'No -SharePointClientId specified' }
                        )
                    })
            }

            $map['exo.admin@contoso.com'] | Should -Be (InModuleScope Maester { Get-MtAffectedObjectUniqueId -System 'EntraID' -Type 'User' -Id 'exo.admin@contoso.com' })
            $map.ContainsKey('a~b!c^d@contoso.com') | Should -BeTrue
            $map.Keys | Should -Not -Contain "'exo.admin@contoso.com"
        }

        Context 'Session cache' {
            BeforeAll {
                # Shapes taken from a live run: Get-MtUser caches a list read as a Hashtable,
                # checks such as Test-MtCaReferencedObjectsExist cache keyed reads with a display name.
                $script:sessionCache = @{
                    'https://graph.microsoft.com/beta/users?$select=id%2CuserPrincipalName%2CuserType&$top=5&$filter=userType+eq+%27Member%27' = @{
                        '@odata.context' = 'https://graph.microsoft.com/beta/$metadata#users(id,userPrincipalName,userType)'
                        value            = @(
                            @{ id = '77777777-7777-7777-7777-777777777777'; userPrincipalName = 'sam.member@contoso.com'; userType = 'Member' }
                            @{ id = '88888888-8888-8888-8888-888888888888'; userPrincipalName = 'kim.member@contoso.com'; userType = 'Member' }
                        )
                    }
                    'https://graph.microsoft.com/beta/users/99999999-9999-9999-9999-999999999999' = [PSCustomObject]@{
                        id = '99999999-9999-9999-9999-999999999999'; userPrincipalName = 'lee@contoso.com'; displayName = 'Support'
                    }
                    'https://graph.microsoft.com/beta/groups?$select=id' = @{ value = @(@{ id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; displayName = 'Sales' }) }
                    'https://graph.microsoft.com/v1.0/$batch_{"requests":[]}' = $null
                    'https://graph.microsoft.com/v1.0/organization' = 'not an object'
                    'https://graph.microsoft.com/v1.0/security/runHuntingQuery_{"Query":"x"}' = @(1, 2)
                }

                $script:mapWithCache = {
                    param([switch] $IncludeSessionCache)
                    InModuleScope Maester -Parameters @{ Cache = $script:sessionCache; Include = $IncludeSessionCache.IsPresent } {
                        param($Cache, $Include)
                        $previous = $__MtSession.GraphCache
                        $__MtSession.GraphCache = $Cache
                        try {
                            Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{ Tests = @() }) -IncludeSessionCache:$Include
                        } finally {
                            $__MtSession.GraphCache = $previous
                        }
                    }
                }
            }

            It 'Should map users that were only read as part of a list' {
                $map = & $script:mapWithCache -IncludeSessionCache

                $map['sam.member@contoso.com'] | Should -BeLike 'object-*'
                $map['kim.member@contoso.com'] | Should -BeLike 'object-*'
                $map['77777777-7777-7777-7777-777777777777'] | Should -Be $map['sam.member@contoso.com']
            }

            It 'Should map users from keyed reads without their display name' {
                $map = & $script:mapWithCache -IncludeSessionCache

                $map['lee@contoso.com'] | Should -BeLike 'object-*'
                $map.ContainsKey('Support') | Should -BeFalse
                # Non-user objects carry no UPN
                $map.ContainsKey('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') | Should -BeFalse
            }

            It 'Should use the same token as the inventory record of the same user' {
                $tokens = InModuleScope Maester -Parameters @{ Cache = $script:sessionCache } {
                    param($Cache)
                    $previous = $__MtSession.GraphCache
                    $__MtSession.GraphCache = $Cache
                    try {
                        $inventory = @(Get-MtAffectedObject -MaesterResults ([PSCustomObject]@{ Tests = @() }))
                        $map = Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{ AffectedObjects = $inventory }) -IncludeSessionCache
                        [PSCustomObject]@{
                            Inventory = ($inventory | Where-Object Id -EQ '99999999-9999-9999-9999-999999999999').UniqueId
                            Map       = $map['lee@contoso.com']
                        }
                    } finally {
                        $__MtSession.GraphCache = $previous
                    }
                }

                $tokens.Inventory | Should -Not -BeNullOrEmpty
                $tokens.Map | Should -Be $tokens.Inventory
            }

            It 'Should ignore the session cache unless asked to' {
                $map = & $script:mapWithCache

                $map.Count | Should -Be 0
            }

            It 'Should redact a list-read UPN from a test title in the json' {
                $map = & $script:mapWithCache -IncludeSessionCache
                $json = [PSCustomObject]@{
                    Title = 'User should be blocked from using legacy authentication (sam.member@contoso.com)'
                } | ConvertTo-Json -Compress

                $redacted = InModuleScope Maester -Parameters @{ Json = $json; Map = $map } {
                    param($Json, $Map)
                    ConvertTo-MtRedactedReportContent -Content $Json -ReplacementMap $Map -JsonEncoded
                }

                $redacted | Should -Not -BeLike '*sam.member@contoso.com*'
                ($redacted | ConvertFrom-Json).Title | Should -BeLike 'User should be blocked from using legacy authentication (object-*)'
            }
        }

        Context 'Signed-in account' {
            It 'Should map the signed-in account even when the run never read it from Graph' {
                $map = InModuleScope Maester {
                    Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{
                            Account   = 'ops.admin@contoso.com'
                            MgContext = [PSCustomObject]@{ Account = 'ops.admin@contoso.com' }
                        })
                }

                $map['ops.admin@contoso.com'] | Should -BeLike 'object-*'
                $map.Count | Should -Be 1
            }

            It 'Should reuse the object id token when the account was read from Graph' {
                $tokens = InModuleScope Maester -Parameters @{ Cache = $script:sessionCache } {
                    param($Cache)
                    $previous = $__MtSession.GraphCache
                    $__MtSession.GraphCache = $Cache
                    try {
                        $map = Get-MtUserIdentityReplacementMap -IncludeSessionCache -MaesterResults ([PSCustomObject]@{ Account = 'sam.member@contoso.com' })
                        [PSCustomObject]@{
                            Account = $map['sam.member@contoso.com']
                            Id      = $map['77777777-7777-7777-7777-777777777777']
                        }
                    } finally {
                        $__MtSession.GraphCache = $previous
                    }
                }

                $tokens.Account | Should -Be $tokens.Id
            }

            It 'Should not map <Case>' -ForEach @(
                @{ Case = 'the placeholder of an unconnected run'; Account = 'Account (not connected to Graph)' }
                @{ Case = 'an app-only run without account'; Account = $null }
            ) {
                $map = InModuleScope Maester -Parameters @{ Account = $Account } {
                    param($Account)
                    Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{ Account = $Account; MgContext = $null })
                }

                $map.Count | Should -Be 0
            }

            It 'Should map the account of every tenant in a merged result' {
                $map = InModuleScope Maester {
                    Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{
                            Tenants = @(
                                [PSCustomObject]@{ Account = 'admin@contoso.com' }
                                [PSCustomObject]@{ Account = 'admin@fabrikam.com' }
                            )
                        })
                }

                $map.Keys | Should -Contain 'admin@contoso.com'
                $map.Keys | Should -Contain 'admin@fabrikam.com'
            }
        }

        It 'Should map the user principal name of a user object' {
            $map = InModuleScope Maester {
                Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{
                        AffectedObjects = @(
                            [PSCustomObject]@{
                                System = 'EntraID'; Type = 'User'; UniqueId = 'object-user-003'
                                Id = '44444444-4444-4444-4444-444444444444'; DisplayName = 'Jane Doe'
                                UserPrincipalName = 'jane@contoso.com'
                            }
                        )
                    })
            }

            $map['jane@contoso.com'] | Should -Be 'object-user-003'
        }

        It 'Should give a user read by UPN and by object id one token whatever the inventory order' {
            $map = InModuleScope Maester {
                Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{
                        AffectedObjects = @(
                            [PSCustomObject]@{
                                System = 'EntraID'; Type = 'User'; UniqueId = 'object-by-upn'
                                Id = 'jane@contoso.com'; UserPrincipalName = 'jane@contoso.com'
                            }
                            [PSCustomObject]@{
                                System = 'EntraID'; Type = 'User'; UniqueId = 'object-by-id'
                                Id = '44444444-4444-4444-4444-444444444444'; DisplayName = 'Jane Doe'
                                UserPrincipalName = 'jane@contoso.com'
                            }
                        )
                    })
            }

            $map['jane@contoso.com'] | Should -Be 'object-by-id'
            $map['44444444-4444-4444-4444-444444444444'] | Should -Be 'object-by-id'
        }

        It 'Should keep users passed without an id apart so each one is redacted' {
            $result = InModuleScope Maester {
                $records = ConvertTo-MtAffectedObjectRecord -GraphObjectType Users -GraphObjects @(
                    [PSCustomObject]@{ displayName = 'Jane Doe'; userPrincipalName = 'jane@contoso.com' }
                    [PSCustomObject]@{ displayName = 'Bob Smith'; userPrincipalName = 'bob@contoso.com' }
                )
                $inventory = @(Get-MtAffectedObject -ExcludeSessionCache -MaesterResults ([PSCustomObject]@{
                            Tests = @([PSCustomObject]@{
                                    Id = 'MT.1001'; ResultDetail = [PSCustomObject]@{ RelatedObjects = $records; TestResult = '' }
                                })
                        }))
                [PSCustomObject]@{
                    Inventory = $inventory
                    Map       = Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{ AffectedObjects = $inventory })
                }
            }

            $result.Inventory.Count | Should -Be 2
            # Same token the signed-in account or a users/{upn} cache read of Bob would get.
            $result.Map['bob@contoso.com'] | Should -Be (InModuleScope Maester { Get-MtAffectedObjectUniqueId -System 'EntraID' -Type 'User' -Id 'bob@contoso.com' })
            $result.Map['Bob Smith'] | Should -BeLike 'object-*'
            $result.Map['bob@contoso.com'] | Should -Be $result.Map['Bob Smith']
            $result.Map['bob@contoso.com'] | Should -Not -Be $result.Map['jane@contoso.com']
        }

        It 'Should redact a UPN written in different casing' {
            $redacted = InModuleScope Maester {
                ConvertTo-MtRedactedReportContent -Content 'Owner Jane@Contoso.com' -ReplacementMap @{ 'jane@contoso.com' = 'object-user-001' }
            }

            $redacted | Should -Be 'Owner object-user-001'
        }

        It 'Should redact a quoted UPN and an apostrophe in the local part' {
            $redacted = InModuleScope Maester {
                ConvertTo-MtRedactedReportContent -Content "upn = 'jane@contoso.com'; owner o'brien@contoso.com." -ReplacementMap @{
                    'jane@contoso.com'    = 'object-user-001'
                    "o'brien@contoso.com" = 'object-user-002'
                }
            }

            $redacted | Should -Be "upn = 'object-user-001'; owner object-user-002."
        }

        It 'Should redact a quoted UPN with ~, ! or ^ in the local part' {
            $redacted = InModuleScope Maester {
                ConvertTo-MtRedactedReportContent -Content "owner 'a~b!c^d@contoso.com'" -ReplacementMap @{ 'a~b!c^d@contoso.com' = 'object-user-001' }
            }

            $redacted | Should -Be "owner 'object-user-001'"
        }

        It 'Should replace a UPN whole when its local part is also a display name' {
            $redacted = InModuleScope Maester {
                ConvertTo-MtRedactedReportContent -Content 'jdoe@contoso.com and jdoe' -ReplacementMap @{
                    'jdoe@contoso.com' = 'object-user-001'
                    'jdoe'             = 'object-user-001'
                }
            }

            $redacted | Should -Be 'object-user-001 and object-user-001'
        }

        It 'Should still redact a display name inside an unknown UPN' {
            $redacted = InModuleScope Maester {
                ConvertTo-MtRedactedReportContent -Content 'Jane.Doe@other.com' -ReplacementMap @{ 'Jane' = 'object-user-001' }
            }

            $redacted | Should -Be 'object-user-001.Doe@other.com'
        }

        It 'Should redact a large tenant quickly' {
            $elapsed = InModuleScope Maester {
                $map = @{}
                foreach ($i in 1..20000) {
                    $map["user$i@contoso.com"] = "object-$i"
                    $map[[guid]::NewGuid().ToString()] = "object-$i"
                }
                $content = (1..5000 | ForEach-Object { "{""Name"":""MT.1033: user$_@contoso.com must have MFA""}" }) -join ','
                (Measure-Command { $null = ConvertTo-MtRedactedReportContent -Content $content -ReplacementMap $map -JsonEncoded }).TotalSeconds
            }

            # A single alternation of every key took minutes at this size.
            $elapsed | Should -BeLessThan 20
        }

        It 'Should carry the user principal name from related objects into the inventory' {
            $inventory = InModuleScope Maester {
                $record = ConvertTo-MtAffectedObjectRecord -GraphObjectType Users -GraphObjects ([PSCustomObject]@{
                        id = '55555555-5555-5555-5555-555555555555'; displayName = 'Jane Doe'; userPrincipalName = 'jane@contoso.com'
                    })
                Get-MtAffectedObject -ExcludeSessionCache -MaesterResults ([PSCustomObject]@{
                        Tests = @([PSCustomObject]@{
                                Id = 'MT.1001'; ResultDetail = [PSCustomObject]@{ RelatedObjects = @($record); TestResult = '' }
                            })
                    })
            }

            $inventory.UserPrincipalName | Should -Be 'jane@contoso.com'
        }

        It 'Should collect user objects from every tenant of a merged result' {
            $map = InModuleScope Maester -Parameters @{ Results = $script:results } {
                param($Results)
                Get-MtUserIdentityReplacementMap -MaesterResults ([PSCustomObject]@{ Tenants = @($Results) })
            }

            $map['Jane Doe'] | Should -Be 'object-user-001'
        }

        It 'Should redact values from plain text content' {
            $redacted = InModuleScope Maester {
                ConvertTo-MtRedactedReportContent -Content 'Jane Doe failed the check' -ReplacementMap @{ 'Jane Doe' = 'object-user-001' }
            }

            $redacted | Should -Be 'object-user-001 failed the check'
        }

        It 'Should redact values that json escaping would otherwise hide' {
            $displayName = 'Jane "JD" O\Doe'
            $json = InModuleScope Maester -Parameters @{ DisplayName = $displayName } {
                param($DisplayName)
                $content = [PSCustomObject]@{ name = $DisplayName } | ConvertTo-Json -Compress
                ConvertTo-MtRedactedReportContent -Content $content -ReplacementMap @{ $DisplayName = 'object-user-001' } -JsonEncoded
            }

            $json | Should -Be '{"name":"object-user-001"}'
        }

        It 'Should redact values next to the escapes Windows PowerShell writes for quotes and html characters' {
            # Windows PowerShell's ConvertTo-Json writes ' < > & as \u0027 \u003c \u003e \u0026.
            $content = '{"s":"displayName = \u0027Jane Doe\u0027, upn = \u0027jane@contoso.com\u0027 \u003cb\u003e"}'
            $json = InModuleScope Maester -Parameters @{ Content = $content } {
                param($Content)
                ConvertTo-MtRedactedReportContent -Content $Content -JsonEncoded -ReplacementMap @{
                    'Jane Doe'         = 'object-user-001'
                    'jane@contoso.com' = 'object-user-001'
                }
            }

            $json | Should -Be '{"s":"displayName = \u0027object-user-001\u0027, upn = \u0027object-user-001\u0027 \u003cb\u003e"}'
        }

        It 'Should return the content unchanged when the map is empty' {
            $redacted = InModuleScope Maester {
                ConvertTo-MtRedactedReportContent -Content 'Jane Doe failed the check' -ReplacementMap @{}
            }

            $redacted | Should -Be 'Jane Doe failed the check'
        }

        It 'Should not rewrite the middle of an unrelated word' {
            # A service account called Test must not turn TestResult into a token, which would
            # also rename json properties and leave the report unparseable.
            $redacted = InModuleScope Maester {
                $content = '{"Title":"Testing scope","TestResult":"Latest TestResults show Test only"}'
                ConvertTo-MtRedactedReportContent -Content $content -ReplacementMap @{ 'Test' = 'object-user-001' }
            }

            $redacted | Should -Be '{"Title":"Testing scope","TestResult":"Latest TestResults show object-user-001 only"}'
            { $redacted | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should never rename a json property that equals a display name' {
            $redacted = InModuleScope Maester {
                $content = [PSCustomObject]@{ Severity = 'High'; Title = 'Severity of Severity' } | ConvertTo-Json -Compress
                ConvertTo-MtRedactedReportContent -Content $content -ReplacementMap @{ 'Severity' = 'object-user-001' } -JsonEncoded
            }

            $redacted | Should -Be '{"Severity":"High","Title":"object-user-001 of object-user-001"}'
            ($redacted | ConvertFrom-Json).Severity | Should -Be 'High'
        }

        It 'Should redact json values that contain escaped quotes around a property-like text' {
            $redacted = InModuleScope Maester {
                $content = [PSCustomObject]@{ Note = 'say "Jane Doe": hi'; Owner = 'Jane Doe' } | ConvertTo-Json -Compress
                ConvertTo-MtRedactedReportContent -Content $content -ReplacementMap @{ 'Jane Doe' = 'object-user-001' } -JsonEncoded
            }

            $parsed = $redacted | ConvertFrom-Json
            $parsed.Note | Should -Be 'say "object-user-001": hi'
            $parsed.Owner | Should -Be 'object-user-001'
        }

        It 'Should prefer the longest matching value' {
            $redacted = InModuleScope Maester {
                ConvertTo-MtRedactedReportContent -Content 'Jane Doe Admin and Jane Doe' -ReplacementMap @{
                    'Jane Doe'       = 'object-a'
                    'Jane Doe Admin' = 'object-b'
                }
            }

            $redacted | Should -Be 'object-b and object-a'
        }
    }
}
