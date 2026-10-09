function Test-MtCheckEidscaCR03 {
    <#
    .SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire is 'true'

    .DESCRIPTION
    Specifies whether reviewers will receive reminder emails

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy
    .remindersEnabled with Test-MtEidscaCR03
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.CR03',
        Title = 'Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire.',
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

    $tenantValue = Test-MtEidscaCR03
    return ($tenantValue -eq 'true')
}
