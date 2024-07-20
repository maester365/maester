<#
.SYNOPSIS
    Checks if guest invitiations are restricted to admins

.DESCRIPTION
    Only users with the Guest Inviter role SHOULD be able to invite guest users.

.EXAMPLE
    Test-MtCisaGuestInvitation

    Returns true if guest invitiations are restricted to admins

.LINK
    https://maester.dev/docs/commands/Test-MtCisaGuestInvitation
#>
function Test-MtCisaGuestInvitation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion v1.0

    $testResult = $result.allowInvitesFrom -eq "adminsAndGuestInviters"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant restricts who can invite guests:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant allows anyone to invite guests."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}