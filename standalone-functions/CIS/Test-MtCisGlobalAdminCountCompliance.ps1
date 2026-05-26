function Test-MtCisGlobalAdminCountCompliance {
    <#
    .SYNOPSIS
    Checks if the number of Global Admins is between 2 and 4

    .DESCRIPTION
    A minimum of two users and a maximum of four users SHALL be provisioned with the Global Administrator role.
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisGlobalAdminCountCompliance
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

    try {
        Write-Verbose 'Getting role'
        $role = Get-MgDirectoryRole -All | Where-Object {
            $_.id -eq '62e90394-69f5-4237-9190-012177145e10'
        } # Global Administrator

        Write-Verbose 'Getting role assignments'
        $assignments = Get-MgDirectoryRoleMember -DirectoryRoleId $role.id -All

        Write-Verbose 'Getting list of user identities assigned the Global Administrator role'
        $globalAdministrators = $assignments | Where-Object {
            $_.'@odata.type' -eq '#microsoft.graph.user'
        }

        $testResult = ($globalAdministrators | Measure-Object).Count -ge 2 -and ($globalAdministrators | Measure-Object).Count -le 4
        return $testResult
    } catch {
        return $null
    }

}
