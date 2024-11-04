BeforeDiscovery {
    $TeamsMeetingPolicy = Get-CsTeamsMeetingPolicy
    Write-Verbose "Found $($TeamsMeetingPolicy.Count) Teams Meeting policies"
    $TeamsMeetingPolicyGlobal = $TeamsMeetingPolicy | Where-Object {$_.Identity -eq "Global"}
    Write-Verbose "Filtered $( $TeamsMeetingPolicyGlobal.Count) Global Teams Meeting policy"
    #$TeamsEventsPolicy = Get-CsTeamsEventsPolicy
    #Write-Verbose "Found $($TeamsEventsPolicy.Count) Teams Events policies"
}

Describe "Teams Meeting policies" -Tag "Maester", "Teams", "MeetingPolicy" {

    It "Configure which users are allowed to present in Teams meetings" -Tag "AllowParticipantGiveRequestControl" {
        $TeamsMeetingPolicyGlobal.AllowParticipantGiveRequestControl | Should -Be $false -Because "Only allow users with presenter rights to share content during meetings. Restricting who can present limits meeting disruptions and reduces the risk of unwanted or inappropriate content being shared."
    }

    It "Only invited users should be automatically admitted to Teams meetings" -Tag "AutoAdmittedUsers" {
        ($TeamsMeetingPolicyGlobal.AutoAdmittedUsers -eq "InvitedUsers") | Should -Be $true -Because "Users who aren’t invited to a meeting shouldn’t be let in automatically, because it increases the risk of data leaks, inappropriate content being shared, or malicious actors joining. If only invited users are automatically admitted, then users who weren’t invited will be sent to a meeting lobby. The host can then decide whether or not to let them in."
    }

    It "Restrict anonymous users from joining meetings" -Tag "AllowAnonymousUsersToJoinMeeting" {
        $TeamsMeetingPolicyGlobal.AllowAnonymousUsersToJoinMeeting | Should -Be $false -Because "By restricting anonymous users from joining Microsoft Teams meetings, you have full control over meeting access. Anonymous users may not be from your organization and could have joined for malicious purposes, such as gaining information about your organization through conversations."
    }
        
    It "Restrict anonymous users from starting Teams meetings" -Tag "AllowAnonymousUsersToStartMeeting" {
        $TeamsMeetingPolicyGlobal.AllowAnonymousUsersToStartMeeting | Should -Be $false -Because "If anonymous users are allowed to start meetings, they can admit any users from the lobbies, authenticated or otherwise. Anonymous users haven’t been authenticated, which can increase the risk of data leakage."
    }

    It "Limit external participants from having control in a Teams meeting" -Tag "AllowExternalParticipantGiveRequestControl" {
        $TeamsMeetingPolicyGlobal.AllowExternalParticipantGiveRequestControl | Should -Be $false -Because "External participants are users that are outside your organization. Limiting their permission to share content, add new users, and more protects your organization’s information from data leaks, inappropriate content being shared, or malicious actors joining the meeting."
    }

    It "Restrict dial-in users from bypassing a meeting lobby " -Tag "AllowPSTNUsersToBypassLobby" {
        $TeamsMeetingPolicyGlobal.AllowPSTNUsersToBypassLobby | Should -Be $false -Because "Dial-in users aren’t authenticated though the Teams app. Increase the security of your meetings by preventing these unknown users from bypassing the lobby and immediately joining the meeting."
    }
}

#Describe "Teams Events policies" -Tag "Maester", "Teams", "EventsPolicy" {
#    $TeamsEventsPolicy | fl
#}

