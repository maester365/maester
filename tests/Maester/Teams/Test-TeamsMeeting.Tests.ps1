BeforeDiscovery {
    try {

        $TeamsMeetingPolicy = Get-CsTeamsMeetingPolicy
        Write-Verbose "Found $($TeamsMeetingPolicy.Count) Teams Meeting policies"
    } catch {
        Write-Verbose "Session is not established, run Connect-MicrosoftTeams before requesting access token"
    }
}

Describe "Teams Meeting policies" -Tag "Maester", "Teams", "MeetingPolicy", "All" {

    It "MT.1037 Only users with Presenter role are allowed to present in Teams meetings" -Tag "MT.1037" -TestCases @{ TeamsMeetingPolicy = $TeamsMeetingPolicy } {

        $result = Test-MtTeamsRestrictParticipantGiveRequestControl -TeamsMeetingPolicy $TeamsMeetingPolicy
        $result | Should -Be $true -Because "Standard attendees in a Teams meeting should not be allowed to present in Teams meetings unless they are assigned the Presenter role."

    }

    It "MT.1038 Only invited users should be automatically admitted to Teams meetings" -Tag "MT.1038" -TestCases @{ TeamsMeetingPolicy = $TeamsMeetingPolicy } {
        #($TeamsMeetingPolicyGlobal.AutoAdmittedUsers -eq "InvitedUsers")
        $TeamsMeetingPolicyGlobal = $TeamsMeetingPolicy | Where-Object { $_.Identity -eq "Global" }
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AutoAdmittedUsers

        if ($result -eq "InvitedUsers") {
            $testResultMarkdown = "Well done. AutoAdmittedUsers is $($result)`n`n"
        } else {
            $testResultMarkdown = "AutoAdmittedUsers in [Meeting policies]($portalLink_MeetingPolicy) should be InvitedUsers and is $($result) `n`n"
        }
        $testDetailsMarkdown = "Users who aren’t invited to a meeting shouldn’t be let in automatically, because it increases the risk of data leaks, inappropriate content being shared, or malicious actors joining. If only invited users are automatically admitted, then users who weren’t invited will be sent to a meeting lobby. The host can then decide whether or not to let them in."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be "InvitedUsers" -Because "AutoAdmittedUsers should be InvitedUsers"
    }

    It "MT.1039 Restrict anonymous users from joining meetings" -Tag "MT.1039" -TestCases @{ TeamsMeetingPolicy = $TeamsMeetingPolicy } {

        $TeamsMeetingPolicyGlobal = $TeamsMeetingPolicy | Where-Object { $_.Identity -eq "Global" }
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AllowAnonymousUsersToJoinMeeting

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AllowAnonymousUsersToJoinMeeting is $($result)`n`n"
        } else {
            $testResultMarkdown = "AllowAnonymousUsersToJoinMeeting in [Meeting policies]($portalLink_MeetingPolicy) should be False and is $($result) `n`n"
        }
        $testDetailsMarkdown = "By restricting anonymous users from joining Microsoft Teams meetings, you have full control over meeting access. Anonymous users may not be from your organization and could have joined for malicious purposes, such as gaining information about your organization through conversations."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be $false -Because "AllowAnonymousUsersToJoinMeeting should be False"
    }

    It "MT.1040 Restrict anonymous users from starting Teams meetings" -Tag "MT.1040" -TestCases @{ TeamsMeetingPolicy = $TeamsMeetingPolicy }{

        $TeamsMeetingPolicyGlobal = $TeamsMeetingPolicy | Where-Object { $_.Identity -eq "Global" }
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AllowAnonymousUsersToStartMeeting

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AllowAnonymousUsersToStartMeeting is $($result)`n`n"
        } else {
            $testResultMarkdown = "AllowAnonymousUsersToStartMeeting in [Meeting policies]($portalLink_MeetingPolicy) should be False and is $($result) `n`n"
        }
        $testDetailsMarkdown = "If anonymous users are allowed to start meetings, they can admit any users from the lobbies, authenticated or otherwise. Anonymous users haven’t been authenticated, which can increase the risk of data leakage."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be $false -Because "AllowAnonymousUsersToStartMeeting should be False"
    }

    It "MT.1041 Limit external participants from having control in a Teams meeting" -Tag "MT.1041" -TestCases @{ TeamsMeetingPolicy = $TeamsMeetingPolicy }{

        $TeamsMeetingPolicyGlobal = $TeamsMeetingPolicy | Where-Object { $_.Identity -eq "Global" }
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AllowExternalParticipantGiveRequestControl

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AllowExternalParticipantGiveRequestControl is $($result)`n`n"
        } else {
            $testResultMarkdown = "AllowExternalParticipantGiveRequestControl in [Meeting policies]($portalLink_MeetingPolicy) should be False and is $($result) `n`n"
        }
        $testDetailsMarkdown = "External participants are users that are outside your organization. Limiting their permission to share content, add new users, and more protects your organization’s information from data leaks, inappropriate content being shared, or malicious actors joining the meeting."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be $false -Because "AllowExternalParticipantGiveRequestControl should be False"
    }

    It "MT.1042 Restrict dial-in users from bypassing a meeting lobby " -Tag "MT.1042" -TestCases @{ TeamsMeetingPolicy = $TeamsMeetingPolicy }{

        $TeamsMeetingPolicyGlobal = $TeamsMeetingPolicy | Where-Object { $_.Identity -eq "Global" }
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AllowPSTNUsersToBypassLobby

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AllowPSTNUsersToBypassLobby is $($result)`n`n"
        } else {
            $testResultMarkdown = "AllowPSTNUsersToBypassLobby in [Meeting policies]($portalLink_MeetingPolicy) should be False and is $($result) `n`n"
        }
        $testDetailsMarkdown = "Dial-in users aren’t authenticated though the Teams app. Increase the security of your meetings by preventing these unknown users from bypassing the lobby and immediately joining the meeting."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be $false -Because "AllowPSTNUsersToBypassLobby should be False"
    }
}
