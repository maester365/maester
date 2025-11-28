<#
.SYNOPSIS
    Tests if app registration owners have Multi-Factor Authentication (MFA) enabled.

.DESCRIPTION
    This function checks all Entra ID app registrations and verifies that their owners have MFA registered.

.OUTPUTS
    [bool] - Returns $true if all owners have MFA, $false if any owners lack MFA, $null if skipped

.EXAMPLE
    Test-MtAppRegistrationOwnersWithoutMFA

.LINK
    https://maester.dev/docs/commands/Test-MtAppRegistrationOwnersWithoutMFA
#>

function Test-MtAppRegistrationOwnersWithoutMFA {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks MFA for all app registration owners.')]
    [OutputType([bool])]
    param()

    # Early exit if Graph connection is not available
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose "Step 1: Retrieving app registrations with owners..."

        # Retrieve all applications with their owners in a single API call
        # The $expand parameter includes owner details to minimize round trips
        $allApps = Invoke-MtGraphRequest -RelativeUri 'applications?$expand=owners' -ErrorAction Stop
        $appsWithOwners = $allApps | Where-Object { $_.owners.Count -gt 0 }

        Write-Verbose "Found $($appsWithOwners.Count) app registrations with owners."

        # Early exit if no apps with owners are found
        if ($appsWithOwners.Count -eq 0) {
            Add-MtTestResultDetail -Result "No app registrations with owners found."
            return $true
        }

        Write-Verbose "Step 2: Collecting unique owner IDs for MFA lookup..."

        # Use HashSet for efficient duplicate detection in large datasets
        $uniqueOwnerIdsSet = [System.Collections.Generic.HashSet[string]]::new()

        foreach ($app in $appsWithOwners) {
            foreach ($owner in $app.owners) {
                if ($owner.id) {
                    [void]$uniqueOwnerIdsSet.Add($owner.id)
                }
            }
        }

        # Convert to array for further processing
        $uniqueOwnerIds = @($uniqueOwnerIdsSet)
        Write-Verbose "Found $($uniqueOwnerIds.Count) unique owners to check."

        Write-Verbose "Step 3: Retrieving MFA registration status for owners..."

        # Query MFA registration details for all users

        $userRegistrationResponse = Invoke-MtGraphRequest -RelativeUri 'reports/authenticationMethods/userRegistrationDetails?$select=id,userPrincipalName,userDisplayName,isMfaRegistered' -ErrorAction Stop

        # Create lookup hashtable
        $ownerHashTable = @{}
        $uniqueOwnerIds | ForEach-Object { $ownerHashTable[$_] = $true }

        # Filter API response to only include relevant owners
        $relevantUserRegistrations = $userRegistrationResponse | Where-Object {
            $_.id -and $ownerHashTable.ContainsKey($_.id)
        }

        # Build MFA status lookup table for quick access during owner processing
        $mfaStatusLookup = @{}
        $validUserDetails = 0

        foreach ($userDetail in $relevantUserRegistrations) {
            $mfaStatusLookup[$userDetail.id] = @{
                isMfaRegistered   = $userDetail.isMfaRegistered -eq $true
                userDisplayName   = $userDetail.userDisplayName
                userPrincipalName = $userDetail.userPrincipalName
            }
            $validUserDetails++
        }

        Write-Verbose "Retrieved MFA status for $validUserDetails relevant owners."

        Write-Verbose "Step 4: Analyzing MFA compliance for each owner..."

        # Pre-allocate collections for better performance in large environments
        $ownersWithoutMFA = [System.Collections.Generic.List[PSCustomObject]]::new()
        $skippedOwners = [System.Collections.Generic.List[PSCustomObject]]::new()
        $totalOwners = 0
        $ownersWithMFA = 0

        # Process each app and its owners to determine MFA compliance
        foreach ($app in $appsWithOwners) {
            foreach ($owner in $app.owners) {
                $totalOwners++

                # Check if we have MFA data for this owner
                if ($mfaStatusLookup.ContainsKey($owner.id)) {
                    if ($mfaStatusLookup[$owner.id].isMfaRegistered) {
                        $ownersWithMFA++
                    } else {
                        # Owner found but doesn't have MFA registered
                        $ownersWithoutMFA.Add([PSCustomObject]@{
                                AppName    = $app.displayName
                                AppId      = $app.appId
                                OwnerName  = $mfaStatusLookup[$owner.id].userDisplayName
                                OwnerUPN   = $mfaStatusLookup[$owner.id].userPrincipalName
                                OwnerID    = $owner.id
                                MFAMethods = "No MFA registered"
                            })
                    }
                } else {
                    # Owner not found in MFA data - likely service principal or disabled user

                    $ownerName = if ($owner.displayName) { $owner.displayName }
                    elseif ($owner.userPrincipalName) { $owner.userPrincipalName }
                    else { "Unknown" }

                    $ownerType = if ($owner.'@odata.type' -eq '#microsoft.graph.servicePrincipal') {
                        "Service Principal"
                    } elseif ($owner.'@odata.type' -eq '#microsoft.graph.user') {
                        "User (possibly disabled)"
                    } else {
                        "Unknown type"
                    }

                    $skippedOwners.Add([PSCustomObject]@{
                            AppName   = $app.displayName
                            AppId     = $app.appId
                            OwnerName = $ownerName
                            OwnerUPN  = $owner.userPrincipalName
                            OwnerID   = $owner.id
                            OwnerType = $ownerType
                            Reason    = "Could not retrieve MFA status ($ownerType)"
                        })

                    Write-Verbose "Owner $ownerName ($ownerType) not found in registration details - likely service principal or disabled user."
                }
            }
        }

        Write-Verbose "Summary - Apps: $($appsWithOwners.Count), Total owners: $totalOwners, With MFA: $ownersWithMFA, Without MFA: $($ownersWithoutMFA.Count), Skipped: $($skippedOwners.Count)"

        # Determine test result: pass only if no owners lack MFA
        $testPassed = ($ownersWithoutMFA.Count -eq 0)

        # Generate detailed markdown report for the results
        if ($testPassed) {
            # All owners have MFA - generate success report
            $testResultMarkdown = "**Well done!** All app registration owners have MFA registered."

            if ($totalOwners -gt 0) {
                $testResultMarkdown += "`n`n**Summary:** Found $($appsWithOwners.Count) applications. All valid owners are registered for MFA.`n`n"

                # Include information about skipped owners
                if ($skippedOwners.Count -gt 0) {
                    $testResultMarkdown += "`n`n**Note:** $($skippedOwners.Count) owner(s) could not be checked (service principals or disabled users)."

                    # Detailed breakdown of skipped owners
                    $testResultMarkdown += "`n`n**Skipped Owners:**`n`n| Application | Owner | Type | Reason |`n| --- | --- | --- | --- |`n"

                    foreach ($skippedOwner in $skippedOwners) {
                        $appLink = "[$($skippedOwner.AppName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($skippedOwner.AppId))"

                        $ownerDisplay = if ($skippedOwner.OwnerType -like "*User*") {
                            "[$($skippedOwner.OwnerName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($skippedOwner.OwnerID))"
                        } else {
                            $skippedOwner.OwnerName
                        }

                        $testResultMarkdown += "| $appLink | $ownerDisplay | $($skippedOwner.OwnerType) | $($skippedOwner.Reason) |`n"
                    }
                }
            }
        } else {
            #  Owners without MFA - generate failure report
            $testResultMarkdown = "**Action Required:** Found $($ownersWithoutMFA.Count) applications with owners who have not registered for Multi-Factor Authentication (MFA).`n`n"

            # Create table of owners who need to register MFA
            $testResultMarkdown += "`n`n**App Registration Owners Without MFA:**`n`n| Application | Owner | UPN | MFA Status |`n| --- | --- | --- | --- |`n"

            foreach ($owner in $ownersWithoutMFA) {
                # Generate portal links for quick access to fix issues
                $appLink = "[$($owner.AppName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($owner.AppId))"
                $userLink = "[$($owner.OwnerUPN)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($owner.OwnerID))"
                $testResultMarkdown += "| $appLink | $($owner.OwnerName) | $userLink | $($owner.MFAMethods) |`n"
            }

            # Include skipped owners section
            if ($skippedOwners.Count -gt 0) {
                $testResultMarkdown += "`n`n**Skipped Owners (Could Not Check MFA):**`n`n| Application | Owner | Type | Reason |`n| --- | --- | --- | --- |`n"

                foreach ($skippedOwner in $skippedOwners) {
                    $appLink = "[$($skippedOwner.AppName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($skippedOwner.AppId))"

                    # Create user links for actual users only
                    $ownerDisplay = if ($skippedOwner.OwnerType -like "*User*") {
                        "[$($skippedOwner.OwnerName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($skippedOwner.OwnerID))"
                    } else {
                        $skippedOwner.OwnerName
                    }

                    $testResultMarkdown += "| $appLink | $ownerDisplay | $($skippedOwner.OwnerType) | $($skippedOwner.Reason) |`n"
                }
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

    } catch {
        Write-Error $_.Exception.Message
        Add-MtTestResultDetail -Result "**Error** checking app registration owners: $($_.Exception.Message)"
        return $false
    }

    return $testPassed
}