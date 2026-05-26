function Test-MtCisCloudAdminCompliance {
    <#
    .SYNOPSIS
    Checks if Global Admins are cloud users

    .DESCRIPTION
    Ensure Administrative accounts are cloud-only
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisCloudAdminCompliance
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
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    try {
        Write-Verbose 'Getting Global Admin role'
        $role = Get-MgDirectoryRole -All | Where-Object {
            $_.id -eq '62e90394-69f5-4237-9190-012177145e10'
        } # Global Administrator

        Write-Verbose 'Getting role members'
        $assignments = Get-MgDirectoryRoleMember -DirectoryRoleId $role.id -All

        Write-Verbose 'Filtering for users'
        $globalAdministrators = $assignments | Where-Object {
            $_.'@odata.type' -eq '#microsoft.graph.user'
        }

        $userIds = @($globalAdministrators.Id)

        Write-Verbose 'Requesting users onPremisesSyncEnabled property'
        $users = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users' -UniqueId $userIds -Select id, displayName, onPremisesSyncEnabled

        Write-Verbose 'Filtering users for onPremisesSyncEnabled'
        $result = $users | Where-Object {
            $_.onPremisesSyncEnabled -eq $true
        }

        $testResult = ($result | Measure-Object).Count -eq 0

        $sortSplat = @{
            Property = @(
                @{
                    Expression = 'onPremisesSyncEnabled'
                    Descending = $true
                },
                @{
                    Expression = 'displayName'
                }
            )
        }
        return $testResult
    } catch {
        return $null
    }

}
