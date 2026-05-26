function Test-MtGroupCreationRestrictedCompliance {
    <#
    .SYNOPSIS
    Checks if Microsoft 365 Group creation is restricted to approved users.

    .DESCRIPTION
    By default, all users can create Microsoft 365 Groups. This can lead to sprawl, security risks and compliance issues.

    Creating groups should be restricted to users who have undergone training and understand the responsibilities of group ownership, governance and compliance requirements.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtGroupCreationRestrictedCompliance
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
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose 'Test-MtGroupCreationRestricted: Checking if Microsoft 365 Group creation is restricted to approved users.'

    try {
        $settings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/settings' -ApiVersion 'beta'

        $groupCreationRestricted = $false

        $enableGroupCreation = $settings.values | Where-Object { $_.name -eq 'EnableGroupCreation' }

        if ($null -ne $enableGroupCreation) {
            # If the setting is not found, it means that group creation is not restricted.
            $groupCreationRestricted = ($enableGroupCreation.value -eq 'false')
        }

        if ($groupCreationRestricted) {
        } else {
        }

        return $groupCreationRestricted
    } catch {
        return $null
    }

}
