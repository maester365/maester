function Test-MtUserAccessAdminCompliance {
    <#
    .SYNOPSIS
    Checks if any Global Admins have User Access Control permissions at the Root Scope

    .DESCRIPTION
    Ensure that no one has permanent access to all subscriptions through the Root Scope.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtUserAccessAdminCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Checking if connected to Graph"


    Write-Verbose "Getting all User Access Administrators at Root Scope"

    try {
        $userAccessResult = Invoke-MtAzureRequest -RelativeUri 'providers/Microsoft.Authorization/roleAssignments' -Filter 'atScope()' -ApiVersion '2022-04-01'

        if ($null -eq $userAccessResult) {
            return $null
        }

        $userAccessAdmins = Get-ObjectProperty $userAccessResult 'value'

        # Get the count of role assignments
        $roleAssignmentCount = $userAccessAdmins | Measure-Object | Select-Object -ExpandProperty Count

        $testResult = $roleAssignmentCount -eq 0
        return $testResult
    }
    catch {
        return $null
    }


}
