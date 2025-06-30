<#
.SYNOPSIS
    Check if owners of app registrations have MFA enabled.
.DESCRIPTION
    This test checks all app registration owners to ensure they have multi-factor authentication (MFA) enabled.
    App registrations without owners or with owners lacking MFA present security risks.
.EXAMPLE
    Test-MtAppRegistrationOwnersMFA
    Returns true if all app registration owners have MFA enabled, otherwise returns false.
.LINK
    https://maester.dev/docs/commands/Test-MtAppRegistrationOwnersWithoutMFA
#>
function Test-MtAppRegistrationOwnerWithoutMFA {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks MFA for all app registration owners.')]
    [OutputType([bool])]
    param(
    )

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose "Step 1: Retrieving all app registrations..."
        # First, get all applications
        $allApps = Invoke-MtGraphRequest -RelativeUri 'applications?$select=id,displayName,appId' -ErrorAction Stop
        Write-Verbose "Found $($allApps.Count) total app registrations."

        Write-Verbose "Step 2: Filtering apps that have owners..."
        $appsWithOwners = @()
        
        foreach ($app in $allApps) {
            try {
                # Check if the app has owners
                $owners = Invoke-MtGraphRequest -RelativeUri "applications/$($app.id)/owners?`$select=id" -ErrorAction Stop
                
                if ($owners.id) {
                    $appsWithOwners += $app
                    Write-Verbose "App '$($app.displayName)' has $($owners.Count) owner(s)."
                }
                else {
                    Write-Verbose "App '$($app.displayName)' has no owners - skipping."
                }
            }
            catch {
                Write-Verbose "Error checking owners for app '$($app.displayName)': $($_.Exception.Message) - skipping."
                continue
            }
        }
        
        Write-Verbose "Found $($appsWithOwners.Count) app registrations with owners."
        
        if ($appsWithOwners.Count -eq 0) {
            $testResultMarkdown = "No app registrations with owners found."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        }

        Write-Verbose "Step 3: Checking MFA for owners of apps with owners..."
        $riskyOwners = @()
        $totalOwners = 0
        $ownersWithMFA = 0
        $skippedOwners = 0

        foreach ($app in $appsWithOwners) {
            Write-Verbose "Processing app: $($app.displayName)"
            
            try {
                # Get owners of the app registration
                $owners = Invoke-MtGraphRequest -RelativeUri "applications/$($app.id)/owners" -ErrorAction Stop
                
                # Check MFA for each owner
                foreach ($owner in $owners) {
                    $totalOwners++
                    Write-Verbose "Checking MFA for owner: $($owner.displayName)"
                    
                    try {
                        # Get user's authentication methods
                        $authMethods = Invoke-MtGraphRequest -RelativeUri "users/$($owner.id)/authentication/methods" -ErrorAction Stop
                        Write-Verbose "Retrieved authentication methods for owner: $($owner.displayName)"
                        
                        # Check for MFA methods
                        $hasMFA = $false
                        $mfaMethods = @()
                        
                        #Check if user has multiple authentication methods
                        if (-not $hasMFA) {
                            $nonPasswordMethods = $authMethods.value | Where-Object { 
                                $_.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' -and
                                $_.'@odata.type' -ne '#microsoft.graph.temporaryAccessPassAuthenticationMethod'
                            }
                            
                            if ($nonPasswordMethods.Count -gt 0) {
                                Write-Verbose "Fallback: Found $($nonPasswordMethods.Count) non-password authentication methods for $($owner.displayName)"
                                $hasMFA = $true
                                $mfaMethods += "Other authentication methods detected ($($nonPasswordMethods.Count) methods)"
                            }
                        }
                        #
                        if ($hasMFA) {
                            $ownersWithMFA++
                            Write-Verbose "Owner $($owner.displayName) has MFA enabled: $($mfaMethods -join ', ')"
                        } else {
                            Write-Verbose "Owner $($owner.displayName) does NOT have MFA enabled."
                            $riskyOwners += [PSCustomObject]@{
                                AppName = $app.displayName
                                AppId = $app.appId
                                OwnerName = $owner.displayName
                                OwnerUPN = $owner.userPrincipalName
                                MFAMethods = "None"
                            }
                        }
                    }
                    catch {
                        $skippedOwners++
                        Write-Verbose "Error checking MFA for owner $($owner.displayName): $($_.Exception.Message) - skipping this owner."
                        continue
                    }
                }
            }
            catch {
                Write-Verbose "Error getting owners for app $($app.displayName): $($_.Exception.Message) - skipping MFA check."
                continue
            }
        }

        Write-Verbose "Summary - Total apps with owners: $($appsWithOwners.Count), Total owners checked: $totalOwners, Owners with MFA: $ownersWithMFA, Owners without MFA: $($riskyOwners.Count), Owners skipped: $skippedOwners"

        # Determine overall result
        $return = ($riskyOwners.Count -eq 0)
        
        if ($return) {
            $testResultMarkdown = "Well done. All app registration owners have MFA enabled."
            if ($totalOwners -gt 0) {
                $testResultMarkdown += "`n`n**Summary:** $ownersWithMFA/$totalOwners owners have MFA enabled across $($appsWithOwners.Count) applications with assigned owners."
                if ($skippedOwners -gt 0) {
                    $testResultMarkdown += "`n`n⚠ **Note:** $skippedOwners owners could not be checked due to errors."
                }
            }
        } else {
            $testResultMarkdown = "Found $($riskyOwners.Count) app registration owner(s) without MFA enabled.`n`n"
            
            # Add summary statistics
            $testResultMarkdown += "**Summary:**`n"
            $testResultMarkdown += "- Total apps with owners: $($appsWithOwners.Count)`n"
            $testResultMarkdown += "- Total owners checked: $totalOwners`n"
            $testResultMarkdown += "- Owners with MFA: $ownersWithMFA`n"
            $testResultMarkdown += "- Owners without MFA: $($riskyOwners.Count)`n"
            if ($skippedOwners -gt 0) {
                $testResultMarkdown += "- Owners skipped (errors): $skippedOwners`n"
            }
            $testResultMarkdown += "`n"
            
            # Create table for owners without MFA
            $testResultMarkdown += "**App Registration Owners Without MFA:**`n`n"
            $testResultMarkdown += "| Application Name | Application ID | Owner Name | Owner UPN | MFA Status |`n"
            $testResultMarkdown += "| --- | --- | --- | --- | --- |`n"
            
            foreach ($owner in $riskyOwners) {
                $appMdLink = "[$($owner.AppName)](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($owner.AppId)/isMSAApp~/false)"
                $testResultMarkdown += "| $appMdLink | $($owner.AppId) | $($owner.OwnerName) | $($owner.OwnerUPN) | $($owner.MFAMethods) |`n"
                Write-Verbose "Adding owner $($owner.OwnerName) without MFA for app $($owner.AppName) to results."
            }
        }
        
        Add-MtTestResultDetail -Result $testResultMarkdown
        
    } catch {
        $return = $false
        Write-Error $_.Exception.Message
        Add-MtTestResultDetail -Result "Error occurred while checking app registration owners: $($_.Exception.Message)"
    }
    
    return $return
}