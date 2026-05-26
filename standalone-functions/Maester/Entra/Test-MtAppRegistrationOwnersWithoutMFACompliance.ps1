function Test-MtAppRegistrationOwnersWithoutMFACompliance {
    <#
    .SYNOPSIS
    Tests if app registration owners have Multi-Factor Authentication (MFA) enabled.

    .DESCRIPTION
    This function checks all Entra ID app registrations and verifies that their owners have MFA registered.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAppRegistrationOwnersWithoutMFACompliance
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
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    # Early exit if Graph connection is not available

    try {
        Write-Verbose "Step 1: Retrieving app registrations with owners..."

        # Retrieve all applications with their owners in a single API call
        # The $expand parameter includes owner details to minimize round trips
        $allApps = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/applications?$expand=owners' -ErrorAction Stop
        $appsWithOwners = $allApps | Where-Object { $_.owners.Count -gt 0 }

        Write-Verbose "Found $($appsWithOwners.Count) app registrations with owners."

        # Early exit if no apps with owners are found
        if ($appsWithOwners.Count -eq 0) {
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

        $userRegistrationResponse = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?$select=id,userPrincipalName,userDisplayName,isMfaRegistered' -ErrorAction Stop

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

            if ($totalOwners -gt 0) {

                # Include information about skipped owners
                if ($skippedOwners.Count -gt 0) {

                    # Detailed breakdown of skipped owners

                    foreach ($skippedOwner in $skippedOwners) {
                        $appLink = "[$($skippedOwner.AppName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($skippedOwner.AppId))"

                        $ownerDisplay = if ($skippedOwner.OwnerType -like "*User*") {
                            "[$($skippedOwner.OwnerName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($skippedOwner.OwnerID))"
                        } else {
                            $skippedOwner.OwnerName
                        }

                    }
                }
            }
        } else {
            #  Owners without MFA - generate failure report

            # Create table of owners who need to register MFA

            foreach ($owner in $ownersWithoutMFA) {
                # Generate portal links for quick access to fix issues
                $appLink = "[$($owner.AppName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($owner.AppId))"
                $userLink = "[$($owner.OwnerUPN)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($owner.OwnerID))"
            }

            # Include skipped owners section
            if ($skippedOwners.Count -gt 0) {

                foreach ($skippedOwner in $skippedOwners) {
                    $appLink = "[$($skippedOwner.AppName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($skippedOwner.AppId))"

                    # Create user links for actual users only
                    $ownerDisplay = if ($skippedOwner.OwnerType -like "*User*") {
                        "[$($skippedOwner.OwnerName)]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($skippedOwner.OwnerID))"
                    } else {
                        $skippedOwner.OwnerName
                    }

                }
            }
        }


    } catch {
        Write-Error $_.Exception.Message
        return $false
    }

    return $testPassed

}
