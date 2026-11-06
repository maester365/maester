function Test-MtCisaCloudGlobalAdmin {
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
    [MaesterTest(
        Id = 'CISA.MS.AAD.7.3',
        Title = 'Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers.',
        Product = 'entra',
        Feature = 'roles',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1556.007', 'T1078.002', 'T1078.004'),
        Control = 'cisa-scuba:MS.AAD.7.3',
        Service = 'Graph',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'merill', 'mrdos010')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # This check reads Global Administrators only; CIS.M365.1.1.1 reads every administrative role.
    $globalAdministratorRoleId = '62e90394-69f5-4237-9190-012177145e10'
    $users = @(Get-MtRoleUserSyncStatus -RoleId $globalAdministratorRoleId)

    $result = @($users | Where-Object { $_.onPremisesSyncEnabled -eq $true })

    $testResult = ($result|Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no hybrid Global Administrators."
    } else {
        $testResultMarkdown = "Your tenant has 1 or more hybrid Global Administrators:`n`n%TestResult%"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType UserRole -GraphObjects $result

    return $testResult
}
