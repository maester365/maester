function Test-MtDisaEntraLogExport {
    <#
    .SYNOPSIS
    Checks that a Microsoft Entra diagnostic setting sends the log categories DISA names.

    .DESCRIPTION
    DISA Microsoft Entra ID STIG (V-270227, CAT II): Microsoft Entra ID must be configured to transfer logs to another server for storage, analysis, and reporting.

    This test runs CISA.MS.AAD.4.1 (Test-MtCisaDiagnosticSettings). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaEntraLogExport

    Returns the result of CISA.MS.AAD.4.1 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270227
    #>
    [MaesterTest(
        Id = 'DISA.V-270227',
        Title = 'Microsoft Entra ID must be configured to transfer logs to another server for storage, analysis, and reporting.',
        Product = 'entra',
        Feature = 'monitoring',
        Area = 'logging-and-detection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1685.002',
        Control = 'disa-stig-entra-id:V-270227',
        Service = ('Graph', 'Azure'),
        License = 'AAD_PREMIUM',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The log categories that a diagnostic setting must send. DISA names eight.
        [string[]] $RequiredLogCategory = ('SignInLogs', 'AuditLogs', 'ServicePrincipalSignInLogs', 'ManagedIdentitySignInLogs', 'UserRiskEvents', 'RiskyUsers', 'RiskyServicePrincipals', 'ServicePrincipalRiskEvents')
    )

    return Test-MtCisaDiagnosticSettings -RequiredLogCategory $RequiredLogCategory
}
