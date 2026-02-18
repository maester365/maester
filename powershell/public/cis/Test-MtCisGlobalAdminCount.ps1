<#
.SYNOPSIS
    Checks if the number of Global Admins is between 2 and 4

.DESCRIPTION
    A minimum of two users and a maximum of four users SHALL be provisioned with the Global Administrator role.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisGlobalAdminCount

    Returns true if only 2 to 4 users are eligible to be global admins

.LINK
    https://maester.dev/docs/commands/Test-MtCisGlobalAdminCount
#>
function Test-MtCisGlobalAdminCount {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }
    
    try {
        Write-Verbose 'Getting role'
        $role = Get-MtRole | Where-Object {
            $_.id -eq '62e90394-69f5-4237-9190-012177145e10'
        } # Global Administrator

        Write-Verbose 'Getting role assignments'
        $assignments = Get-MtRoleMember -RoleId $role.id

        Write-Verbose 'Getting list of user identities assigned the Global Administrator role'
        $globalAdministrators = $assignments | Where-Object {
            $_.'@odata.type' -eq '#microsoft.graph.user'
        }

        $testResult = ($globalAdministrators | Measure-Object).Count -ge 2 -and ($globalAdministrators | Measure-Object).Count -le 4
        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant has two or more and four or fewer Global Administrators:`n`n%TestResult%"
        } else {
            $testResultMarkdown = 'Your tenant does not have the appropriate number of Global Administrators.'
        }

        Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType Users -GraphObjects $globalAdministrators
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
