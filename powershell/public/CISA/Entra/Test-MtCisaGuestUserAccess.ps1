<#
.SYNOPSIS
    Checks if guests use proper role template

.DESCRIPTION

    Guest users SHOULD have limited or restricted access to Azure AD directory objects.

.EXAMPLE
    Test-MtCisaGuestUserAccess

    Returns true if guests use proper role template
#>

Function Test-MtCisaGuestUserAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $guestRoles = @(
        "a0b1b346-4d3e-4e8b-98f8-753987be4970",
        "10dae51f-b6af-4016-8d66-8c2a99b929b3",
        "2af84b1e-32c8-42b7-82bc-daa82404023b"
    )
    $roles = Get-MtRole
    $roles = $roles | Where-Object {`
        $_.id -in $guestRoles
    }

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion v1.0

    $testResult = $result.guestUserRoleId -eq "10dae51f-b6af-4016-8d66-8c2a99b929b3" -or `
        $result.guestUserRoleId -eq "2af84b1e-32c8-42b7-82bc-daa82404023b"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant guest users will be a restricted role:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant guest users do not use a restricted role."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}