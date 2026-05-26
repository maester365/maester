function Test-MtCisaCloudGlobalAdminCompliance {
    <#
    .SYNOPSIS
    Checks if Global Admins are cloud users

    .DESCRIPTION
    Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaCloudGlobalAdminCompliance
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

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $role = Get-MgDirectoryRole -All | Where-Object {`
        $_.id -eq "62e90394-69f5-4237-9190-012177145e10" } # Global Administrator

    $assignments = Get-MtRoleMember -roleId $role.id

    $globalAdministrators = $assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"
    }

    $userIds = @($globalAdministrators.Id)

    $users = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users' -UniqueId $userIds -Select id,displayName,onPremisesSyncEnabled

    $result = $users | Where-Object {`
        $_.onPremisesSyncEnabled -eq $true
    }

    $testResult = ($result|Measure-Object).Count -eq 0
    return $testResult

}
