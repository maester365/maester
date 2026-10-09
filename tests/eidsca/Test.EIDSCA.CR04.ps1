function Test-MtCheckEidscaCR04 {
    <#
    .SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Consent request duration (days) is less than or equal to 30

    .DESCRIPTION
    Specifies the duration the request is active before it automatically expires if no decision is applied

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy
    .requestDurationInDays with Test-MtEidscaCR04
    and passes when it -le 30.
    #>
    [MaesterTest(
        Id = 'EIDSCA.CR04',
        Title = 'Consent Framework - Admin Consent Request - Consent request duration (days).',
        Severity = 'High',
        Category = 'EIDSCA',
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

    $tenantValue = Test-MtEidscaCR04
    return ($tenantValue -le 30)
}
