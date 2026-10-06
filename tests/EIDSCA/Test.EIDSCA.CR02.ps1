function Test-MtCheckEidscaCR02 {
    <#
    .SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests is 'true'

    .DESCRIPTION
    Specifies whether reviewers will receive notifications

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy
    .notifyReviewers with Test-MtEidscaCR02
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.CR02',
        Title = 'Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests.',
        Severity = 'Medium',
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

    $tenantValue = Test-MtEidscaCR02
    return ($tenantValue -eq 'true')
}
