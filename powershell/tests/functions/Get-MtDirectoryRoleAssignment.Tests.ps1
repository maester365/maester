BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Get-MtDirectoryRoleAssignment
}

Describe 'Get-MtDirectoryRoleAssignment' -Tag 'Unit' {
    BeforeAll {
        function Get-GraphErrorRecord ([string]$Code) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Response status code does not indicate success.'),
                'InvokeGraphHttpResponseException',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new("{`"error`":{`"code`":`"$Code`"}}")
            $errorRecord
        }
    }

    BeforeEach {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'active-1'; principalId = 'user-1'; roleDefinitionId = 'role-1' }
        } -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleAssignments' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'pim-active-1'; principalId = 'user-1'; roleDefinitionId = 'role-1' }
        } -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleAssignmentScheduleInstances' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'eligible-1'; principalId = 'user-2'; roleDefinitionId = 'role-1' }
        } -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleEligibilityScheduleInstances' }
    }

    It 'reads active and eligible assignments from the PIM APIs on <Plan>' -ForEach @(
        @{ Plan = 'P2' }
        @{ Plan = 'Governance' }
    ) {
        Mock -ModuleName Maester Get-MtLicenseInformation { $Plan }.GetNewClosure()

        $result = Get-MtDirectoryRoleAssignment

        $result.EligibleChecked | Should -BeTrue
        $result.Assignments.id | Should -Be @('pim-active-1', 'eligible-1')
        $result.Assignments.AssignmentType | Should -Be @('Active', 'Eligible')
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 0 -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleAssignments' }
    }

    It 'leaves out activated eligible roles from the active assignments' {
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }

        $null = Get-MtDirectoryRoleAssignment -MemberStatus Active

        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $RelativeUri -eq 'roleManagement/directory/roleAssignmentScheduleInstances' -and $Filter -eq "assignmentType eq 'Assigned'"
        }
    }

    It 'reads only role assignments on <Plan>' -ForEach @(
        @{ Plan = 'Free' }
        @{ Plan = 'P1' }
    ) {
        Mock -ModuleName Maester Get-MtLicenseInformation { $Plan }.GetNewClosure()

        $result = Get-MtDirectoryRoleAssignment

        $result.EligibleChecked | Should -BeFalse
        $result.Assignments.id | Should -Be 'active-1'
        $result.Assignments.AssignmentType | Should -Be 'Active'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 0 -ParameterFilter { $RelativeUri -like '*ScheduleInstances' }
    }

    It 'uses role assignments when the PIM APIs reject the tenant license' {
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-GraphErrorRecord -Code 'AadPremiumLicenseRequired')
        } -ParameterFilter { $RelativeUri -like '*ScheduleInstances' }

        $result = Get-MtDirectoryRoleAssignment

        $result.EligibleChecked | Should -BeFalse
        $result.Assignments.id | Should -Be 'active-1'
    }

    It 'rethrows other PIM errors' {
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-GraphErrorRecord -Code 'Authorization_RequestDenied')
        } -ParameterFilter { $RelativeUri -like '*ScheduleInstances' }

        { Get-MtDirectoryRoleAssignment } | Should -Throw -ErrorId 'InvokeGraphHttpResponseException'
    }

    It 'filters by role and expands the principal when asked' {
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P1' }

        $null = Get-MtDirectoryRoleAssignment -RoleId '62e90394-69f5-4237-9190-012177145e10' -ExpandPrincipal

        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $RelativeUri -eq 'roleManagement/directory/roleAssignments' -and
            $Filter -eq "roleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'" -and
            $QueryParameters.expand -eq 'principal'
        }
    }

    It 'uses the Graph cache unless asked not to' {
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P1' }

        $null = Get-MtDirectoryRoleAssignment -Select 'id', 'principalId'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $RelativeUri -eq 'roleManagement/directory/roleAssignments' -and -not $DisableCache -and ($Select -join ',') -eq 'id,principalId'
        }

        $null = Get-MtDirectoryRoleAssignment -DisableCache
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $RelativeUri -eq 'roleManagement/directory/roleAssignments' -and $DisableCache
        }
    }
}
