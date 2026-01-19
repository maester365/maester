<#
.SYNOPSIS
    Checks if Global Admins are cloud users

.DESCRIPTION
    Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers.

.EXAMPLE
    Test-MtCisaCloudGlobalAdmin

    Returns true if all global admins are cloud users

.LINK
    https://maester.dev/docs/commands/Test-MtCisaCloudGlobalAdmin
#>
function Test-MtCisaCloudGlobalAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $role = Get-MtRole | Where-Object {`
        $_.id -eq "62e90394-69f5-4237-9190-012177145e10" } # Global Administrator

    $assignments = Get-MtRoleMember -roleId $role.id

    $globalAdministrators = $assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"
    }

    $userIds = @($globalAdministrators.Id)

    $users = Invoke-MtGraphRequest -RelativeUri "users" -UniqueId $userIds -Select id,displayName,onPremisesSyncEnabled

    $result = $users | Where-Object {`
        $_.onPremisesSyncEnabled -eq $true
    }

    $testResult = ($result|Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no hybrid Global Administrators."
    } else {
        $testResultMarkdown = "Your tenant has 1 or more hybrid Global Administrators:`n`n%TestResult%"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType UserRole -GraphObjects $result

    return $testResult
}
