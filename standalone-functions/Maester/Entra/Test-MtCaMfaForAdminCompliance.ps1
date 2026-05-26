function Test-MtCaMfaForAdminCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaMfaForAdminCompliance
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

    $AdministrativeRolesToCheck = @(
        '62e90394-69f5-4237-9190-012177145e10',
        '194ae4cb-b126-40b2-bd5b-6091b380977d',
        'f28a1f50-f6e7-4571-818b-6a12f2af6b6c',
        '29232cdf-9323-42fd-ade2-1d097af3e4de',
        'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9',
        '729827e3-9c14-49f7-bb1b-9608f156bbb8',
        'b0f54661-2d74-4c50-afa3-1ec803f12efe',
        'fe930be7-5e62-47db-91af-98c3a49a38b1',
        'c4e39bd9-1100-46d3-8c65-fb160da0071f',
        '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3',
        '158c047a-c907-4556-b7ef-446551a6b5f7',
        '966707d0-3269-4727-9be2-8c3a10f19b9d',
        '7be44c8a-adaf-4e2a-84d6-ab2649e08a13',
        'e8611ab8-c189-46e8-94e1-60213ab1f814'
    )

    try {
        $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq 'enabled' }
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        foreach ($policy in $policies) {
            $PolicyIncludesAllRoles = $true
            $AdministrativeRolesToCheck | ForEach-Object {
                if ( (
                        $_ -notin $policy.conditions.users.includeRoles -and
                        $policy.conditions.users.includeUsers -notcontains 'All'
                    ) -or $_ -in $policy.conditions.users.excludeRoles
                ) {
                    $PolicyIncludesAllRoles = $false
                }
            }
            if (
                (
                    $policy.grantControls.builtInControls -contains 'mfa' -or
                    $policy.grantControls.authenticationStrength.requirementsSatisfied -contains 'mfa'
                ) -and
                $PolicyIncludesAllRoles -and
                $policy.conditions.applications.includeApplications -eq 'All'
            ) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( $result ) {
        } else {
            $testResult = 'No conditional access policy requires multi-factor authentication for all admin roles.'
        }

        return $result
    } catch {
        return $null
    }

}
