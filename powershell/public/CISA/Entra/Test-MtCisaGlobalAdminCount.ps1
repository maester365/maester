<#
.SYNOPSIS
    Checks if Global Admins is an acceptable number

.DESCRIPTION

    A minimum of two users and a maximum of eight users SHALL be provisioned with the Global Administrator role.

.EXAMPLE
    Test-MtCisaGlobalAdminCount

    Returns true if only 2 to 8 users are eligible to be global admins
#>

Function Test-MtCisaGlobalAdminCount {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $role = Get-MtRole | Where-Object {`
        $_.id -eq "62e90394-69f5-4237-9190-012177145e10" }

    $assignments = Get-MtRoleMember -roleId $role.id -All

    $globalAdministrators = $assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"
    }

    $testResult = ($globalAdministrators|Measure-Object).Count -ge 2 -and ($globalAdministrators|Measure-Object).Count -le 8

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has two or more and eight or fewer Global Administrators:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have the appropriate number of Global Administrators."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType Users -GraphObjects $globalAdministrators

    return $testResult
}