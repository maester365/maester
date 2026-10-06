function Test-MtCisGlobalAdminCount {
    <#
    .SYNOPSIS
    Checks if the number of Global Admins is between 2 and 4

    .DESCRIPTION
    A minimum of two users and a maximum of four users SHALL be provisioned with the Global Administrator role.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.1.3, L1)

    .EXAMPLE
    Test-MtCisGlobalAdminCount

    Returns true if only 2 to 4 users are eligible to be global admins

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGlobalAdminCount
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.1.3',
        Title = 'Ensure that between two and four global admins are designated',
        Severity = 'High',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS M365 v7.0.0', 'L1'),
        Service = 'Graph',
        Author = 'NZLostboy',
        Contributor = 'mrdos010'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

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
}
