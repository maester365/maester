BeforeAll {
    . "$PSScriptRoot/../../internal/Get-MtRoleInfo.ps1"

    # Import only the helper functions from the build script without executing the main body.
    # The main execution body (network calls, file writes) lives after '#region Main execution'.
    $buildScriptPath = Resolve-Path "$PSScriptRoot/../../../build/Update-MtRoleDefinitions.ps1"
    $buildContent = Get-Content $buildScriptPath -Raw
    $helperSection = ($buildContent -split [regex]::Escape('#region Main execution'))[0]
    $sb = [scriptblock]::Create($helperSection)
    . $sb
}

Describe 'Get-RoleDataFromMarkdown' {

    Context 'Valid table with 3 roles including 1 privileged' {
        It 'returns 3 entries with correct IsPrivileged flag' {
            $md = @'
## All roles

| Role | Description | ID |
| --- | --- | --- |
| [Global Administrator](#global-administrator) | Can manage all aspects of Azure AD. [![Privileged label icon.](./media/permissions-reference/privileged-label.png)](privileged-roles-permissions.md) | 62e90394-69f5-4237-9190-012177145e10 |
| [Reports Reader](#reports-reader) | Can read sign-in and audit reports. | 4a5d8f65-41da-4de4-8968-e035b65339cf |
| [Search Administrator](#search-administrator) | Can create and manage all aspects of Microsoft Search settings. | 0964bb5e-9bdb-4d7b-ac29-58e794862a40 |
'@
            $result = Get-RoleDataFromMarkdown -Markdown $md
            $result.Count | Should -Be 3
            $privileged = @($result | Where-Object { $_.IsPrivileged })
            $privileged.Count | Should -Be 1
            $privileged[0].Name | Should -Be 'GlobalAdministrator'
        }
    }

    Context 'Blockquote-formatted table (GFM > | ... | syntax)' {
        It 'parses roles and IsPrivileged correctly when table rows use > prefix' {
            $md = @'
## All roles

> [!div class="mx-tableFixed"]
> | Role | Description | ID |
> | --- | --- | --- |
> | [Global Administrator](#global-administrator) | Can manage all aspects of Azure AD. [![Privileged label icon.](./media/permissions-reference/privileged-label.png)](privileged-roles-permissions.md) | 62e90394-69f5-4237-9190-012177145e10 |
> | [Reports Reader](#reports-reader) | Can read sign-in and audit reports. | 4a5d8f65-41da-4de4-8968-e035b65339cf |
'@
            $result = Get-RoleDataFromMarkdown -Markdown $md
            $result.Count | Should -Be 2
            $privileged = @($result | Where-Object { $_.IsPrivileged })
            $privileged.Count | Should -Be 1
            $privileged[0].Name | Should -Be 'GlobalAdministrator'
            ($result | Where-Object { $_.Name -eq 'ReportsReader' }).IsPrivileged | Should -BeFalse
        }

        It 'parses roles correctly when blockquote rows use up to 3 spaces of indentation' {
            $md = @'
## All roles

   > | Role | Description | ID |
   > | --- | --- | --- |
   > | [Global Administrator](#global-administrator) | Description | 62e90394-69f5-4237-9190-012177145e10 |
'@
            # Wrap in @() to prevent PowerShell from unwrapping a single-item list to a bare hashtable
            $result = @(Get-RoleDataFromMarkdown -Markdown $md)
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'GlobalAdministrator'
        }
    }

    Context 'Missing All roles heading' {
        It 'throws an error mentioning All roles' {
            $md = @'
## Other Section

| Role | Description | ID |
| --- | --- | --- |
| [Some Role](#some-role) | Description | 62e90394-69f5-4237-9190-012177145e10 |
'@
            { Get-RoleDataFromMarkdown -Markdown $md } | Should -Throw -ExpectedMessage '*All roles*'
        }
    }

    Context 'Missing table header separator row' {
        It 'throws an error about the header separator' {
            $md = @'
## All roles

| Role | Description | ID |
| [Global Administrator](#global-administrator) | Description | 62e90394-69f5-4237-9190-012177145e10 |
'@
            { Get-RoleDataFromMarkdown -Markdown $md } | Should -Throw -ExpectedMessage '*table header separator*'
        }
    }

    Context 'Table header has fewer than 3 columns' {
        It 'throws an error about column count' {
            $md = @'
## All roles

| Role | ID |
| --- | --- |
| [Global Administrator](#global-administrator) | 62e90394-69f5-4237-9190-012177145e10 |
'@
            { Get-RoleDataFromMarkdown -Markdown $md } | Should -Throw -ExpectedMessage '*column*'
        }
    }

    Context 'Row missing pipe delimiters (too few columns)' {
        It 'skips the malformed row without a terminating error' {
            $md = @'
## All roles

| Role | Description | ID |
| --- | --- | --- |
| [Global Administrator](#global-administrator) | Description | 62e90394-69f5-4237-9190-012177145e10 |
This is a prose line with a guid 11111111-1111-1111-1111-111111111111 but no pipes
'@
            $result = @(Get-RoleDataFromMarkdown -Markdown $md)
            @($result).Count | Should -Be 1
            $result[0].Name | Should -Be 'GlobalAdministrator'
        }
    }

    Context 'Duplicate role names' {
        It 'is handled by the caller deduplication (both entries returned from parser)' {
            $md = @'
## All roles

| Role | Description | ID |
| --- | --- | --- |
| [Global Administrator](#global-administrator) | First | 62e90394-69f5-4237-9190-012177145e10 |
| [Global Administrator](#global-administrator) | Duplicate | 62e90394-69f5-4237-9190-012177145e10 |
'@
            # Parser returns duplicates; caller is responsible for dedup
            $result = Get-RoleDataFromMarkdown -Markdown $md
            $result.Count | Should -Be 2
        }
    }

    Context 'GUID normalization' {
        It 'normalizes parsed GUIDs to lowercase' {
            $md = @'
## All roles

| Role | Description | ID |
| --- | --- | --- |
| [Global Administrator](#global-administrator) | Description | 62e90394-69f5-4237-9190-012177145e10 |
'@
            $result = @(Get-RoleDataFromMarkdown -Markdown $md)
            # GUIDs from the source document are already lowercase; .ToLower() is a no-op safeguard
            $result[0].Id | Should -Be '62e90394-69f5-4237-9190-012177145e10'
        }
    }
}

Describe 'Test-KnownRolesPresent' {

    Context 'All 5 expected roles present' {
        It 'returns true' {
            $roles = [System.Collections.Generic.List[hashtable]]::new()
            @(
                @{ Name = 'GlobalAdministrator'; Id = '62e90394-69f5-4237-9190-012177145e10'; IsPrivileged = $true; DisplayName = 'Global Administrator' }
                @{ Name = 'SecurityAdministrator'; Id = '194ae4cb-b126-40b2-bd5b-6091b380977d'; IsPrivileged = $true; DisplayName = 'Security Administrator' }
                @{ Name = 'UserAdministrator'; Id = 'fe930be7-5e62-47db-91af-98c3a49a38b1'; IsPrivileged = $true; DisplayName = 'User Administrator' }
                @{ Name = 'HelpdeskAdministrator'; Id = '729827e3-9c14-49f7-bb1b-9608f156bbb8'; IsPrivileged = $true; DisplayName = 'Helpdesk Administrator' }
                @{ Name = 'ExchangeAdministrator'; Id = '29232cdf-9323-42fd-ade2-1d097af3e4de'; IsPrivileged = $false; DisplayName = 'Exchange Administrator' }
            ) | ForEach-Object { $roles.Add($_) }

            $result = Test-KnownRolesPresent -Roles $roles
            $result | Should -BeTrue
        }
    }

    Context 'One expected role missing' {
        It 'returns false and emits a warning' {
            $roles = [System.Collections.Generic.List[hashtable]]::new()
            @(
                @{ Name = 'GlobalAdministrator'; Id = '62e90394-69f5-4237-9190-012177145e10'; IsPrivileged = $true; DisplayName = 'Global Administrator' }
                @{ Name = 'SecurityAdministrator'; Id = '194ae4cb-b126-40b2-bd5b-6091b380977d'; IsPrivileged = $true; DisplayName = 'Security Administrator' }
                # UserAdministrator intentionally omitted
                @{ Name = 'HelpdeskAdministrator'; Id = '729827e3-9c14-49f7-bb1b-9608f156bbb8'; IsPrivileged = $true; DisplayName = 'Helpdesk Administrator' }
                @{ Name = 'ExchangeAdministrator'; Id = '29232cdf-9323-42fd-ade2-1d097af3e4de'; IsPrivileged = $false; DisplayName = 'Exchange Administrator' }
            ) | ForEach-Object { $roles.Add($_) }

            $result = Test-KnownRolesPresent -Roles $roles 3>&1
            # Last element is the boolean return; warnings are mixed in via 3>&1
            ($result | Where-Object { $_ -is [bool] }) | Should -BeFalse
        }
    }
}

Describe 'Test-AllGuidsValid' {

    Context 'All GUIDs valid' {
        It 'returns true' {
            $roles = [System.Collections.Generic.List[hashtable]]::new()
            $roles.Add(@{ Name = 'TestRole'; Id = '62e90394-69f5-4237-9190-012177145e10'; IsPrivileged = $false; DisplayName = 'Test Role' })

            $result = Test-AllGuidsValid -Roles $roles
            $result | Should -BeTrue
        }
    }

    Context 'One invalid GUID' {
        It 'returns false and emits a warning' {
            $roles = [System.Collections.Generic.List[hashtable]]::new()
            $roles.Add(@{ Name = 'GoodRole'; Id = '62e90394-69f5-4237-9190-012177145e10'; IsPrivileged = $false; DisplayName = 'Good Role' })
            $roles.Add(@{ Name = 'BadRole'; Id = 'not-a-valid-guid'; IsPrivileged = $false; DisplayName = 'Bad Role' })

            $result = Test-AllGuidsValid -Roles $roles 3>&1
            ($result | Where-Object { $_ -is [bool] }) | Should -BeFalse
        }
    }
}

Describe 'Get-ExistingRoles' {

    Context 'File with 3 roles, 2 overlap with new roles' {
        It 'returns only the 1 role not present in new data (preserved)' {
            $fileContent = @"
    'GlobalAdministrator' = [MtRoleDefinition]::new('62e90394-69f5-4237-9190-012177145e10', `$true)
    'ReportsReader' = [MtRoleDefinition]::new('4a5d8f65-41da-4de4-8968-e035b65339cf', `$false)
    'SystemRole' = [MtRoleDefinition]::new('aaaabbbb-cccc-dddd-eeee-ffffffffffff', `$false)
"@
            $newRoles = [System.Collections.Generic.List[hashtable]]::new()
            $newRoles.Add(@{ Name = 'GlobalAdministrator'; Id = '62e90394-69f5-4237-9190-012177145e10'; IsPrivileged = $true; DisplayName = 'Global Administrator' })
            $newRoles.Add(@{ Name = 'ReportsReader'; Id = '4a5d8f65-41da-4de4-8968-e035b65339cf'; IsPrivileged = $false; DisplayName = 'Reports Reader' })

            $preserved = @(Get-ExistingRoles -FileContent $fileContent -NewRoles $newRoles)
            @($preserved).Count | Should -Be 1
            $preserved[0].Name | Should -Be 'SystemRole'
        }
    }

    Context 'Existing role has same GUID as a renamed new role' {
        It 'does not preserve the old-name entry when its GUID is already covered by a new role' {
            # Simulates: old name 'OldRoleName' was renamed to 'NewRoleName' in public docs.
            # Both share the same GUID. The old entry should NOT be preserved, to avoid
            # two hashtable keys mapping to the same underlying Entra ID role.
            $fileContent = @"
    'OldRoleName' = [MtRoleDefinition]::new('9f06204d-73c1-4d4c-880a-6edb90606fd8', `$false)
    'SystemRole'  = [MtRoleDefinition]::new('aaaabbbb-cccc-dddd-eeee-ffffffffffff', `$false)
"@
            $newRoles = [System.Collections.Generic.List[hashtable]]::new()
            # New data contains the renamed role (same GUID, new name)
            $newRoles.Add(@{ Name = 'NewRoleName'; Id = '9f06204d-73c1-4d4c-880a-6edb90606fd8'; IsPrivileged = $false; DisplayName = 'New Role Name' })

            $preserved = @(Get-ExistingRoles -FileContent $fileContent -NewRoles $newRoles)
            # Only SystemRole should be preserved; OldRoleName should be skipped (GUID already in new data)
            @($preserved).Count | Should -Be 1
            $preserved[0].Name | Should -Be 'SystemRole'
        }
    }
}

Describe 'Get-RoleAliases' {

    Context 'Existing role has same GUID as a renamed new role' {
        It 'returns an alias from the old role name to the new role name' {
            $fileContent = @"
    'OldRoleName' = [MtRoleDefinition]::new('9f06204d-73c1-4d4c-880a-6edb90606fd8', `$false)
    'SystemRole'  = [MtRoleDefinition]::new('aaaabbbb-cccc-dddd-eeee-ffffffffffff', `$false)
"@
            $newRoles = [System.Collections.Generic.List[hashtable]]::new()
            $newRoles.Add(@{ Name = 'NewRoleName'; Id = '9f06204d-73c1-4d4c-880a-6edb90606fd8'; IsPrivileged = $false; DisplayName = 'New Role Name' })

            $aliases = @(Get-RoleAliases -FileContent $fileContent -NewRoles $newRoles)

            @($aliases).Count | Should -Be 1
            $aliases[0].Name | Should -Be 'OldRoleName'
            $aliases[0].CanonicalName | Should -Be 'NewRoleName'
        }
    }

    Context 'Existing alias points at a role renamed again' {
        It 'retargets the alias to the latest canonical role name by GUID' {
            $fileContent = @"
    'CurrentRoleName' = [MtRoleDefinition]::new('9f06204d-73c1-4d4c-880a-6edb90606fd8', `$false)
`$script:MtRoleAliases = @{
    'OldRoleName' = 'CurrentRoleName'
}
"@
            $newRoles = [System.Collections.Generic.List[hashtable]]::new()
            $newRoles.Add(@{ Name = 'NewRoleName'; Id = '9f06204d-73c1-4d4c-880a-6edb90606fd8'; IsPrivileged = $false; DisplayName = 'New Role Name' })

            $aliases = @(Get-RoleAliases -FileContent $fileContent -NewRoles $newRoles)

            @($aliases).Count | Should -Be 2
            ($aliases | Where-Object { $_.Name -eq 'OldRoleName' }).CanonicalName | Should -Be 'NewRoleName'
            ($aliases | Where-Object { $_.Name -eq 'CurrentRoleName' }).CanonicalName | Should -Be 'NewRoleName'
        }
    }
}

Describe 'Update-FileSection' {

    Context 'Marker present in file' {
        It 'replaces content between markers' {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tmpFile -Value @'
before
# BEGIN MARKER
old content
# END MARKER
after
'@
            Update-FileSection -FilePath $tmpFile `
                -BeginMarker '# BEGIN MARKER' `
                -EndMarker '# END MARKER' `
                -NewContent 'new content'

            $result = Get-Content -Path $tmpFile -Raw
            $result | Should -Match 'new content'
            $result | Should -Not -Match 'old content'
            Remove-Item $tmpFile -Force
        }
    }

    Context 'Begin marker missing' {
        It 'throws an error containing the begin marker text' {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tmpFile -Value 'no markers here'

            { Update-FileSection -FilePath $tmpFile `
                    -BeginMarker '# BEGIN MARKER' `
                    -EndMarker '# END MARKER' `
                    -NewContent 'new content' } | Should -Throw -ExpectedMessage '*BEGIN MARKER*'

            Remove-Item $tmpFile -Force
        }
    }
}

Describe 'Get-MtRoleInfo type contract' {

    Context 'Known privileged role' {
        It 'returns an MtRoleDefinition with a valid GUID and IsPrivileged = true' {
            $result = Get-MtRoleInfo -RoleName 'GlobalAdministrator'
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'MtRoleDefinition'
            $result.ToString() | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            $result.IsPrivileged | Should -BeTrue
        }
    }

    Context 'Null guard for empty role name' {
        It 'returns null for whitespace input without throwing' {
            $result = Get-MtRoleInfo -RoleName '   '
            $result | Should -BeNullOrEmpty
        }

        It 'returns null for empty string without throwing' {
            $result = Get-MtRoleInfo -RoleName ''
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Unknown role name' {
        It 'returns null for an unrecognized role name' {
            $result = Get-MtRoleInfo -RoleName 'ThisRoleDoesNotExist99'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Renamed role alias' {
        It 'resolves the legacy Azure AD joined device role name to the current Microsoft Entra role definition' {
            $legacy = Get-MtRoleInfo -RoleName 'AzureADJoinedDeviceLocalAdministrator'
            $current = Get-MtRoleInfo -RoleName 'MicrosoftEntraJoinedDeviceLocalAdministrator'

            $legacy | Should -Not -BeNullOrEmpty
            $current | Should -Not -BeNullOrEmpty
            $legacy.ToString() | Should -Be $current.ToString()
            $legacy.IsPrivileged | Should -Be $current.IsPrivileged
        }
    }
}
