<#
.SYNOPSIS
    Check if owners of app registrations have MFA registered.
.DESCRIPTION
    This test checks all app registration owners to ensure they have multi-factor authentication (MFA) registered.
    App registrations without owners or with owners lacking MFA present security risks.
.EXAMPLE
    Test-MtAppRegistrationOwnersMFA
    Returns true if all app registration owners have MFA registered, otherwise returns false.
.LINK
    https://maester.dev/docs/commands/Test-MtAppRegistrationOwnersWithoutMFA
#>

function Test-MtAppRegistrationOwnerWithoutMFA {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks MFA for all app registration owners.')]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose "Step 1: Retrieving app registrations with owners..."

        # Get all applications and filter on client side.
        $allApps = Invoke-MtGraphRequest -RelativeUri 'applications?$expand=owners' -ErrorAction Stop
        $appsWithOwners = $allApps | Where-Object { $_.owners.Count -gt 0 }

        Write-Verbose "Found $($appsWithOwners.Count) app registrations with owners."

        if ($appsWithOwners.Count -eq 0) {
            Add-MtTestResultDetail -Result "No app registrations with owners found."
            return $true
        }

        Write-Verbose "Step 2: Retrieving MFA status for owners..."

        # Extract unique owner IDs for targeted MFA lookup
        $uniqueOwnerIds = @()
        foreach ($app in $appsWithOwners) {
            foreach ($owner in $app.owners) {
                if ($owner.id -and $uniqueOwnerIds -notcontains $owner.id) {
                    $uniqueOwnerIds += $owner.id
                }
            }
        }
        Write-Verbose "Found $($uniqueOwnerIds.Count) unique owners to check."

        # Get MFA status for all users via userRegistrationDetails API
        $userRegistrationResponse = Invoke-MtGraphRequest -RelativeUri 'reports/authenticationMethods/userRegistrationDetails?$select=id,userPrincipalName,userDisplayName,isMfaRegistered' -ErrorAction Stop

        # Filter to only relevant owners using hashtable for O(1) lookup
        $ownerHashTable = @{}
        $uniqueOwnerIds | ForEach-Object { $ownerHashTable[$_] = $true }

        $userRegistrationResponse = $userRegistrationResponse | Where-Object {
            $_.id -and $ownerHashTable.ContainsKey($_.id)
        }

        # Create lookup hashtable for MFA status from filtered data
        $mfaStatusLookup = @{}
        $validUserDetails = 0

        foreach ($userDetail in $userRegistrationResponse) {
            $mfaStatusLookup[$userDetail.id] = @{
                isMfaRegistered = $userDetail.isMfaRegistered -eq $true
                userDisplayName = $userDetail.userDisplayName
                userPrincipalName = $userDetail.userPrincipalName
            }
            $validUserDetails++
        }

        Write-Verbose "Retrieved MFA status for $validUserDetails relevant owners."

        # Process owners and identify those without MFA
        $ownersWithoutMFa = @()
        $totalOwners = 0
        $ownersWithMFA = 0
        $skippedOwners = 0

        foreach ($app in $appsWithOwners) {
            foreach ($owner in $app.owners) {
                $totalOwners++

                if ($mfaStatusLookup.ContainsKey($owner.id)) {
                    if ($mfaStatusLookup[$owner.id].isMfaRegistered) {
                        $ownersWithMFA++
                    } else {
                        $ownersWithoutMFa += [PSCustomObject]@{
                            AppName = $app.displayName
                            AppId = $app.appId
                            OwnerName = $mfaStatusLookup[$owner.id].userDisplayName
                            OwnerUPN = $mfaStatusLookup[$owner.id].userPrincipalName
                            OwnerID = $owner.id
                            MFAMethods = "No MFA registered"
                        }
                    }
                } else {
                    $skippedOwners++
                    Write-Verbose "Owner $($owner.displayName) not found in registration details - likely service principal or disabled user."
                }
            }
        }

        Write-Verbose "Summary - Apps: $($appsWithOwners.Count), Total owners: $totalOwners, With MFA: $ownersWithMFA, Without MFA: $($ownersWithoutMFa.Count), Skipped: $skippedOwners"

        # Generate results
        $return = ($ownersWithoutMFa.Count -eq 0)

        if ($return) {
            $testResultMarkdown = "Well done. All app registration owners have MFA registered."
            if ($totalOwners -gt 0) {
                $testResultMarkdown += "`n`n**Summary:** $ownersWithMFA/$totalOwners owners have MFA registered across $($appsWithOwners.Count) applications."
                if ($skippedOwners -gt 0) {
                    $testResultMarkdown += "`n`n⚠ **Note:** $skippedOwners owners could not be checked (service principals or disabled users)."
                }
            }
        } else {
            $testResultMarkdown = "Found $($ownersWithoutMFa.Count) app registration owner(s) without MFA registered.`n`n"
            $testResultMarkdown += "**Summary:**`n- Apps with owners: $($appsWithOwners.Count)`n- Total owners: $totalOwners`n- With MFA: $ownersWithMFA`n- Without MFA: $($ownersWithoutMFa.Count)"

            if ($skippedOwners -gt 0) {
                $testResultMarkdown += "`n- Skipped: $skippedOwners"
            }

            $testResultMarkdown += "`n`n**App Registration Owners Without MFA:**`n`n| Application | Owner | UPN | MFA Status |`n| --- | --- | --- | --- |`n"

            foreach ($owner in $ownersWithoutMFa) {
                $appLink = "[$($owner.AppName)](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($owner.AppId))"
                $userLink = "[$($owner.OwnerUPN)](https://portal.azure.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($owner.OwnerID))"
                $testResultMarkdown += "| $appLink | $($owner.OwnerName) | $userLink | $($owner.MFAMethods) |`n"
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

    } catch {
        Write-Error $_.Exception.Message
        Add-MtTestResultDetail -Result "Error checking app registration owners: $($_.Exception.Message)"
        return $false
    }

    return $return
}