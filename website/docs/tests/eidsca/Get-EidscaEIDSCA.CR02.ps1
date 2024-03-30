<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests??? is set to 'true'

.DESCRIPTION

    Specifies whether reviewers will receive notifications

    Queries policies/adminConsentRequestPolicy
    and checks if notifyReviewers is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.CR02

    Returns the value of notifyReviewers at policies/adminConsentRequestPolicy
#>

Function Get-EidscaEIDSCA.CR02 {
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
