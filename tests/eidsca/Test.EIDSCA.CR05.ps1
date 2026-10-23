function Test-MtCheckEidscaCR05 {
    <#
    .SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Admin consent reviewers have valid query scopes is 'true'

    .DESCRIPTION
    Checks that the enabled admin consent workflow has at least one reviewer scope and that every scope has a MicrosoftGraph query with a structurally valid absolute or rooted relative path. A null queryRoot is valid for absolute paths. This structural check does not execute queries, resolve membership, or establish reviewer availability or approval permissions.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy
    .reviewers.Count -gt 0 -and @($result.reviewers with Test-MtEidscaCR05
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.CR05',
        Title = 'Consent Framework - Admin Consent Request - Admin consent reviewers have valid query scopes.',
        Product = 'entra',
        Feature = 'app-consent',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EnabledAdminConsentWorkflow = (Invoke-MtGraphRequest -RelativeUri 'policies/adminConsentRequestPolicy' -ApiVersion beta).isenabled
    if ( $EnabledAdminConsentWorkflow -eq $false ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Admin Consent Workflow is not enabled'
        return $null
    }

    $tenantValue = Test-MtEidscaCR05
    return ($tenantValue -eq 'true')
}
