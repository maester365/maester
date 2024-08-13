<#
.SYNOPSIS
    Checks if guests use proper role template

.DESCRIPTION
    Guest users SHOULD have limited or restricted access to Azure AD directory objects.

.EXAMPLE
    Test-MtCisaGuestUserAccess

    Returns true if guests use proper role template

.LINK
    https://maester.dev/docs/commands/Test-MtCisaGuestUserAccess
#>
function Test-MtCisaGuestUserAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

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

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion v1.0

    $configuredGuestRole = $guestRoles | Where-Object { $_.Id -eq $result.guestUserRoleId }

    if ($configuredGuestRole) {
        # Test passes if guest are configured to a restricted role
        $testResult = $configuredGuestRole.IsRestrictedRole

        if ($testResult) {
            $testResultMarkdown = "Well done. $($configuredGuestRole.DisplayName)"
        } else {
            $testResultMarkdown = "Guest user access is not restricted. $($configuredGuestRole.DisplayName)"
        }
    } else {
        $testResult = $false
        $testResultMarkdown = "Guest user access is using a new role that is not recognized. Please report this [issue](https://github.com/maester365/maester/issues/new) in the Maester project."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}