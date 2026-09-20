Describe 'Test-MtPrivPermanentDirectoryRole' {
    BeforeEach {
        Mock -ModuleName Maester Get-MgContext {
            return [pscustomobject]@{ TenantId = 'tenant-id' }
        }
        Mock -ModuleName Maester Add-MtTestResultDetail
        Mock -ModuleName Maester Get-MtEamClassification {
            return @{
                'control-plane-role'   = 'ControlPlane'
                'management-plane-role' = 'ManagementPlane'
            }
        }
        Mock -ModuleName Maester Invoke-WebRequest
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($RelativeUri -like 'roleManagement/directory/roleAssignments*') {
                return @(
                    [pscustomobject]@{
                        roleDefinitionId = 'control-plane-role'
                        principalId      = 'user-1'
                        directoryScopeId = '/'
                        principal        = [pscustomobject]@{
                            userType       = 'Guest'
                            displayName    = 'Guest User'
                            id             = 'user-1'
                            '@odata.type'  = '#microsoft.graph.user'
                        }
                    }
                    [pscustomobject]@{
                        roleDefinitionId = 'management-plane-role'
                        principalId      = 'user-2'
                        directoryScopeId = '/'
                        principal        = [pscustomobject]@{
                            userType       = 'Guest'
                            displayName    = 'Management User'
                            id             = 'user-2'
                            '@odata.type'  = '#microsoft.graph.user'
                        }
                    }
                )
            }

            return @(
                [pscustomobject]@{ templateId = 'control-plane-role'; displayName = 'Control Plane Role' }
                [pscustomobject]@{ templateId = 'management-plane-role'; displayName = 'Management Plane Role' }
            )
        }
    }

    It 'uses the checked-in classification and does not call GitHub at test time' {
        $result = Test-MtPrivPermanentDirectoryRole -FilteredAccessLevel ControlPlane -FilterPrincipal ExternalUser

        $result | Should -BeTrue
        Should -Invoke Get-MtEamClassification -ModuleName Maester -Exactly 1
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 2
    }

    It 'skips when the checked-in classification cannot be initialized' {
        Mock -ModuleName Maester Get-MtEamClassification { throw 'classification unavailable' }

        $result = Test-MtPrivPermanentDirectoryRole -FilteredAccessLevel ControlPlane -FilterPrincipal ExternalUser

        $result | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'honors changing pipeline tiers and loads classification once' {
        $results = @(
            [pscustomobject]@{ FilterPrincipal = 'ExternalUser'; FilteredAccessLevel = 'ControlPlane' }
            [pscustomobject]@{ FilterPrincipal = 'ExternalUser'; FilteredAccessLevel = 'ManagementPlane' }
        ) | Test-MtPrivPermanentDirectoryRole
        $results.Count | Should -Be 2
        $results | Should -Not -Contain $false
        Should -Invoke Get-MtEamClassification -ModuleName Maester -Exactly 1
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Result -match 'Guest User' -and $Result -notmatch 'Management User'
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Result -match 'Management User' -and $Result -notmatch 'Guest User'
        }
    }

    It 'skips an empty classification instead of reporting no assignments' {
        Mock -ModuleName Maester Get-MtEamClassification { @{} }
        Test-MtPrivPermanentDirectoryRole -FilteredAccessLevel ControlPlane -FilterPrincipal ExternalUser -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }
}
