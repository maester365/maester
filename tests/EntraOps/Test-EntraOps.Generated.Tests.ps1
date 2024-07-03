BeforeDiscovery {
    if(!$EntraOpsPrivilegedEamData) {
        $RbacSystems = ("EntraID", "IdentityGovernance", "DeviceManagement", "ResourceApps")
        if($DefaultFolderClassifiedEam) {
            $EntraOpsPrivilegedEamData = foreach ($RbacSystem in $RbacSystems) {
                if ((Test-Path $DefaultFolderClassifiedEam/$RbacSystem/$RbacSystem.json)) {
                    Get-Content -Path $DefaultFolderClassifiedEam/$RbacSystem/$RbacSystem.json `
                    | ConvertFrom-Json -Depth 10
                }
                else {
                    Write-Warning "No EntraOps data from $($RbacSystem)!"
                }
            }
            New-Variable -Name EntraOpsPrivilegedEamData -Value $EntraOpsPrivilegedEamData -Scope Script -Force
        } else {
           Write-Error `
            'Run EntraOps before executing Maester by using the following cmdlets:
                    Connect-EntraOps -AuthenticationType "UserInteractive" -TenantName "<YourTenantName>"
                    Save-EntraOpsPrivilegedEAMJson -RBACSystems @("EntraID", "ResourceApps", "IdentityGovernance")
            '

         }
    } else {
        Write-Warning "EntraOpsPrivilegedEamData already as variable available!"
    }
}
Describe "Identity Governance role assignment on catalog with privileged objects outside from classification of the administrator" -Tag "EntraOps", "Privileged Scope", "EOPS-01" {
    It "EOPS-01: Privileged Scope - Identity Governance role assignment on catalog with privileged objects outside from classification of the administrator. See https://maester.dev/docs/tests/EOPS-01" {


    <#
        Compare if query of Identity Governance role assignment on catalog with privileged objects outside from classification of the administrator is true to the expected result
        ($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"

    #>

    if ( (!$EntraOpsPrivilegedEamData) ) {
        Add-MtTestResultDetail -SkippedBecause "Classification data of EntraOps missing! Run EntraOps before executing Maester by using the following cmdlets:`n `n Connect-EntraOps -AuthenticationType `"UserInteractive`" -TenantName `"<YourTenantName>`"`n`n $EntraOpsPrivilegedEamData = Get-EntraOpsPrivilegedEAM`nAll checks with data source of EntraOps will be skipped!"
    } else {
        Test-MtEOPS-01 | Should -Be True
    }

}
}

Describe "Permanent and Direct Role Assignments in Azure RBAC on Management Groups without Restricted Management" -Tag "EntraOps", "Privileged Scope", "EOPS-02" {
    It "EOPS-02: Privileged Scope - Permanent and Direct Role Assignments in Azure RBAC on Management Groups without Restricted Management. See https://maester.dev/docs/tests/EOPS-02" {


    <#
        Compare if query of Permanent and Direct Role Assignments in Azure RBAC on Management Groups without Restricted Management is true to the expected result
        ($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"

    #>

    if ( (!(Get-AzContext) -and !(Get-Module EntraOps)) ) {
        Add-MtTestResultDetail -SkippedBecause "EntraOps module has not been loaded and connect to Azure PowerShell is missing. Import module and connect to EntraOps before executing Maester by using the following cmdlets:`nConnect-EntraOps -AuthenticationType `"UserInteractive`" -TenantName `"<YourTenantName>`"`n"
    } else {
        Test-MtEOPS-02 | Should -Be True
    }

}
}

Describe "Group Owners with Privileged Roles and delegated ownership" -Tag "EntraOps", "Privileged Scope", "EOPS-03" {
    It "EOPS-03: Privileged Scope - Group Owners with Privileged Roles and delegated ownership. See https://maester.dev/docs/tests/EOPS-03" {


    <#
        Compare if query of Group Owners with Privileged Roles and delegated ownership is true to the expected result
        ($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"

    #>

    if ( (!$EntraOpsPrivilegedEamData) ) {
        Add-MtTestResultDetail -SkippedBecause "Classification data of EntraOps missing! Run EntraOps before executing Maester by using the following cmdlets:`n `n Connect-EntraOps -AuthenticationType `"UserInteractive`" -TenantName `"<YourTenantName>`"`n`n $EntraOpsPrivilegedEamData = Get-EntraOpsPrivilegedEAM`nAll checks with data source of EntraOps will be skipped!"
    } else {
        Test-MtEOPS-03 | Should -Be True
    }

}
}

Describe "Service Principals with High Privileges Roles on Microsoft Graph and delegation by owners" -Tag "EntraOps", "Privileged Scope", "EOPS-04" {
    It "EOPS-04: Privileged Scope - Service Principals with High Privileges Roles on Microsoft Graph and delegation by owners. See https://maester.dev/docs/tests/EOPS-04" {


    <#
        Compare if query of Service Principals with High Privileges Roles on Microsoft Graph and delegation by owners is true to the expected result
        ($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"

    #>

    if ( (!$EntraOpsPrivilegedEamData) ) {
        Add-MtTestResultDetail -SkippedBecause "Classification data of EntraOps missing! Run EntraOps before executing Maester by using the following cmdlets:`n `n Connect-EntraOps -AuthenticationType `"UserInteractive`" -TenantName `"<YourTenantName>`"`n`n $EntraOpsPrivilegedEamData = Get-EntraOpsPrivilegedEAM`nAll checks with data source of EntraOps will be skipped!"
    } else {
        Test-MtEOPS-04 | Should -Be True
    }

}
}


