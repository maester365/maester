BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Get-MtRoleMember' -Tag 'Unit' {
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
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                id        = 'assignment-1'
                principal = [pscustomobject]@{ id = 'user-1'; '@odata.type' = '#microsoft.graph.user' }
            }
        } -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleAssignments' }
    }

    It 'uses role assignments when the PIM APIs reject the tenant license' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-GraphErrorRecord -Code 'AadPremiumLicenseRequired')
        } -ParameterFilter { $RelativeUri -like '*ScheduleInstances' }

        $members = @(Get-MtRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10')

        $members.id | Should -Be 'user-1'
        $members.AssignmentType | Should -Be 'Active'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleAssignments' }
    }

    It 'stops calling the PIM APIs after the first license rejection' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-GraphErrorRecord -Code 'AadPremiumLicenseRequired')
        } -ParameterFilter { $RelativeUri -like '*ScheduleInstances' }

        $members = @(Get-MtRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10', 'e8611ab8-c189-46e8-94e1-60213ab1f814')

        $members.Count | Should -Be 2
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter { $RelativeUri -like '*ScheduleInstances' }
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 2 -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleAssignments' }
    }

    It 'rethrows other PIM errors' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-GraphErrorRecord -Code 'Authorization_RequestDenied')
        } -ParameterFilter { $RelativeUri -like '*ScheduleInstances' }

        { Get-MtRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10' } | Should -Throw -ErrorId 'InvokeGraphHttpResponseException'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 0 -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleAssignments' }
    }
}
