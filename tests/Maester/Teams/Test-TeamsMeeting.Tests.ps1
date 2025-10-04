BeforeAll {
    try {

        $script:TeamsMeetingPolicy = Get-CsTeamsMeetingPolicy
        Write-Verbose "Found $($script:TeamsMeetingPolicy.Count) Teams Meeting policies"
        $script:TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicy | Where-Object { $_.Identity -eq "Global" }
        Write-Verbose "Found Global Teams Meeting policy ``$($script:TeamsMeetingPolicyGlobal.Identity)``"
    } catch {
        Write-Verbose "Session is not established, run Connect-MicrosoftTeams before requesting access token"
    }
}

Describe "Maester/Teams" -Tag "Maester", "Teams", "MeetingPolicy" {

    It "MT.1037: Only users with Presenter role are allowed to present in Teams meetings" -Tag "MT.1037" -TestCases @{ TeamsMeetingPolicy = $script:TeamsMeetingPolicy } {
        # Secure Score Name: Configure which users are allowed to present in Teams meetings

        $result = Test-MtTeamsRestrictParticipantGiveRequestControl -TeamsMeetingPolicy $TeamsMeetingPolicy
        $result | Should -Be $true -Because "Standard attendees in a Teams meeting should not be allowed to present in Teams meetings unless they are assigned the Presenter role."

    }

    It "MT.1045: Only invited users should be automatically admitted to Teams meetings" -Tag "MT.1045" -TestCases @{ TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal } {
        # This is a "hack" because Pester is not accepting the TestCases variable as $TeamsMeetingPolicyGlobal
        $TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal
        if (-not $TeamsMeetingPolicyGlobal) {
            #Add-MtTestResultDetail -SkippedBecause "No Global Teams Meeting Policy found"
            $TeamsMeetingPolicyGlobal | Should -Not -BeNullOrEmpty -Because "A Global Teams Meeting Policy should exist."
            return
        }
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AutoAdmittedUsers

        if ($result -eq "InvitedUsers") {
            $testResultMarkdown = "Well done. AutoAdmittedUsers is $($result)`n`n"
        } else {
            $testResultMarkdown = "AutoAdmittedUsers in [Meeting policies]($portalLink_MeetingPolicy) should be ``InvitedUsers`` and is ``$($result)`` `n`n"
        }
        $testDetailsMarkdown = "Users who aren’t invited to a meeting shouldn’t be let in automatically, because it increases the risk of data leaks, inappropriate content being shared, or malicious actors joining. If only invited users are automatically admitted, then users who weren’t invited will be sent to a meeting lobby. The host can then decide whether or not to let them in."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be "InvitedUsers" -Because "AutoAdmittedUsers should be InvitedUsers"
    }

    It "MT.1046: Restrict anonymous users from joining meetings" -Tag "MT.1046" -TestCases @{ TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal } {
        # This is a "hack" because Pester is not accepting the TestCases variable as $TeamsMeetingPolicyGlobal
        $TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AllowAnonymousUsersToJoinMeeting

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AllowAnonymousUsersToJoinMeeting is $($result)`n`n"
        } else {
            $testResultMarkdown = "AllowAnonymousUsersToJoinMeeting in [Meeting policies]($portalLink_MeetingPolicy) should be ``False`` and is ``$($result)`` `n`n"
        }
        $testDetailsMarkdown = "By restricting anonymous users from joining Microsoft Teams meetings, you have full control over meeting access. Anonymous users may not be from your organization and could have joined for malicious purposes, such as gaining information about your organization through conversations."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be $false -Because "AllowAnonymousUsersToJoinMeeting should be False"
    }

    It "MT.1047: Restrict anonymous users from starting Teams meetings" -Tag "MT.1047" -TestCases @{ TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal }{
        # This is a "hack" because Pester is not accepting the TestCases variable as $TeamsMeetingPolicyGlobal
        $TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AllowAnonymousUsersToStartMeeting

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AllowAnonymousUsersToStartMeeting is $($result)`n`n"
        } else {
            $testResultMarkdown = "AllowAnonymousUsersToStartMeeting in [Meeting policies]($portalLink_MeetingPolicy) should be ``False`` and is ``$($result)`` `n`n"
        }
        $testDetailsMarkdown = "If anonymous users are allowed to start meetings, they can admit any users from the lobbies, authenticated or otherwise. Anonymous users haven’t been authenticated, which can increase the risk of data leakage."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be $false -Because "AllowAnonymousUsersToStartMeeting should be False"
    }

    It "MT.1048: Limit external participants from having control in a Teams meeting" -Tag "MT.1048" -TestCases @{ TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal }{
        # This is a "hack" because Pester is not accepting the TestCases variable as $TeamsMeetingPolicyGlobal
        $TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AllowExternalParticipantGiveRequestControl

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AllowExternalParticipantGiveRequestControl is $($result)`n`n"
        } else {
            $testResultMarkdown = "AllowExternalParticipantGiveRequestControl in [Meeting policies]($portalLink_MeetingPolicy) should be ``False`` and is ``$($result)`` `n`n"
        }
        $testDetailsMarkdown = "External participants are users that are outside your organization. Limiting their permission to share content, add new users, and more protects your organization’s information from data leaks, inappropriate content being shared, or malicious actors joining the meeting."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be $false -Because "AllowExternalParticipantGiveRequestControl should be False"
    }

    It "MT.1042: Restrict dial-in users from bypassing a meeting lobby " -Tag "MT.1042" -TestCases @{ TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal }{
        # This is a "hack" because Pester is not accepting the TestCases variable as $TeamsMeetingPolicyGlobal
        $TeamsMeetingPolicyGlobal = $script:TeamsMeetingPolicyGlobal
        $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

        if (!(Test-MtConnection Teams)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
            return $null
        }

        $result = $TeamsMeetingPolicyGlobal.AllowPSTNUsersToBypassLobby

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AllowPSTNUsersToBypassLobby is $($result)`n`n"
        } else {
            $testResultMarkdown = "AllowPSTNUsersToBypassLobby in [Meeting policies]($portalLink_MeetingPolicy) should be ``False`` and is ``$($result)`` `n`n"
        }
        $testDetailsMarkdown = "Dial-in users aren’t authenticated though the Teams app. Increase the security of your meetings by preventing these unknown users from bypassing the lobby and immediately joining the meeting."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        $result | Should -Be $false -Because "AllowPSTNUsersToBypassLobby should be False"
    }
}
