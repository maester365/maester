<#
 .Synopsis
  Checks if Teams is configured to only allow users with presenter rights to share content during meetings.

 .Description
  Restricting who can present limits meeting disruptions and reduces the risk of unwanted or inappropriate content being shared.

  Learn more:
  https://techcommunity.microsoft.com/blog/microsoftteamsblog/7-tips-for-safe-online-meetings-and-collaboration-with-microsoft-teams/2072303
  https://learn.microsoft.com/en-us/microsoftteams/meeting-policies-content-sharing

 .Example
  Test-MtTeamsRestrictParticipantGiveRequestControl

.LINK
    https://maester.dev/docs/commands/Test-MtTeamsRestrictParticipantGiveRequestControl
#>
function Test-MtTeamsRestrictParticipantGiveRequestControl {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # The TeamsMeetingPolicy object to check
        # Run `Get-CsTeamsMeetingPolicy` to get the policy
        $TeamsMeetingPolicy
    )

    if (!(Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    try {
        $TeamsMeetingPolicyGlobal = $TeamsMeetingPolicy | Where-Object { $_.Identity -eq 'Global' }

        $result = -not $TeamsMeetingPolicyGlobal.AllowParticipantGiveRequestControl
        Write-Verbose "Test-MtTeamsRestrictParticipantGiveRequestControl: $result"
        if ($result) {
            $testResultMarkdown = "Well done. Only users in the **Presenter** role are configured to share content during Teams meetings.`n`n"
        } else {
            $testResultMarkdown = "Standard attendees who are not in the **Presenter** role are allowed to share content during Teams meetings.`n`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

}
