<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire??? is set to 'true'

.DESCRIPTION

    Specifies whether reviewers will receive reminder emails

    Queries policies/adminConsentRequestPolicy
    and checks if notifyReviewers is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.CR03

    Returns the value of notifyReviewers at policies/adminConsentRequestPolicy
#>

Function Get-EidscaEIDSCA.CR03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    if($result.notifyReviewers -eq 'true') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
