function Test-MtCisaGuestUserAccessCompliance {
    <#
    .SYNOPSIS
    Checks if guests use proper role template

    .DESCRIPTION
    Guest users SHOULD have limited or restricted access to Azure AD directory objects.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaGuestUserAccessCompliance
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

    $guestRoles = @(
        @{
            Id               = "a0b1b346-4d3e-4e8b-98f8-753987be4970"
            DisplayName      = "Guest users have the same access as members (most inclusive)"
            IsRestrictedRole = $false
        },
        @{
            Id               = "10dae51f-b6af-4016-8d66-8c2a99b929b3"
            DisplayName      = "Guest users have limited access to properties and memberships of directory objects"
            IsRestrictedRole = $true
        },
        @{
            Id               = "2af84b1e-32c8-42b7-82bc-daa82404023b"
            DisplayName      = "Guest user access is restricted to properties and memberships of their own directory objects (most restrictive)"
            IsRestrictedRole = $true
        }
    )

    $result = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/authorizationPolicy'.0

    $configuredGuestRole = $guestRoles | Where-Object { $_.Id -eq $result.guestUserRoleId }

    if ($configuredGuestRole) {
        # Test passes if guest are configured to a restricted role
        $testResult = $configuredGuestRole.IsRestrictedRole
    } else {
        $testResult = $false
    }

    return $testResult

}
