function Test-MtCisaGlobalAdminCountCompliance {
    <#
    .SYNOPSIS
    Checks if Global Admins is an acceptable number

    .DESCRIPTION
    A minimum of two users and a maximum of eight users SHALL be provisioned with the Global Administrator role.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaGlobalAdminCountCompliance
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

    $testResult = ($globalAdministrators|Measure-Object).Count -ge 2 -and ($globalAdministrators|Measure-Object).Count -le 8
    return $testResult

}
