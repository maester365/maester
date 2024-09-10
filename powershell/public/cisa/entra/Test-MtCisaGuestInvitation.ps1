<#
.SYNOPSIS
    Checks if guest invitations are restricted to admins

.DESCRIPTION
    Only users with the Guest Inviter role SHOULD be able to invite guest users.

.EXAMPLE
    Test-MtCisaGuestInvitation

    Returns true if guest invitations are restricted to admins

.LINK
    https://maester.dev/docs/commands/Test-MtCisaGuestInvitation
#>
function Test-MtCisaGuestInvitation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion v1.0

    $testResult = ($result.allowInvitesFrom -eq "adminsAndGuestInviters") -or ($result.allowInvitesFrom -eq "none")

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant restricts who can invite guests:`n`nallowInvitesFrom : $($result.allowInvitesFrom)"
    } else {
        $testResultMarkdown = "Your tenant allows anyone to invite guests.`n`nallowInvitesFrom : $($result.allowInvitesFrom)"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}