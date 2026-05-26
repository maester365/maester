function Test-MtCisTeamsLobbyBypassCompliance {
    <#
    .SYNOPSIS
    Ensure only people in my org can bypass the lobby

    .DESCRIPTION
    Only people in my org can bypass the lobby
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisTeamsLobbyBypassCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $null = Get-CsTenant -ErrorAction Stop
    } catch {
        Write-Verbose "Not connected to Microsoft Teams: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    Write-Verbose 'Test-MtCisTeamsLobbyBypass: Testing if only people in my org can bypass the lobby'
    try {
        $TeamsMeetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global | Select-Object -ExpandProperty AutoAdmittedUsers
        if ($TeamsMeetingPolicy -eq 'InvitedUsers' -or $TeamsMeetingPolicy -eq 'EveryoneInCompanyExcludingGuests' -or $TeamsMeetingPolicy -eq 'OrganizerOnly') {
            return $true
        } else {
            return $false
        }
    } catch {
        return $null
    }

}
