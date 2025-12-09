<#
.Synopsis
    This function compares to object arrays

.Description
    Provides the differences in objects between two arrays of objects.

.Example
    Get-ObjectDifference

.LINK
    https://maester.dev/docs/commands/Get-ObjectDifference
#>
function Get-ObjectDifference {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [System.Collections.ArrayList]$excludedObjects,
        [System.Collections.ArrayList]$includedObjects
    )

    # Only get unique values
    $excludedObjects = @($excludedObjects | Select-Object -Unique)
    $includedObjects = @($includedObjects | Select-Object -Unique)
    # Get all the objects that are excluded somewhere but included somewhere else
    $excludedObjectsWithFallback = $excludedObjects | Where-Object {
        $includedObjects -contains $_
    }
    # Get the differences between the two Arrays, so we can find which objects did not have a fallback
    $objectDifferences = @($excludedObjects | Where-Object {
            $excludedObjectsWithFallback -notcontains $_
    })

    return $objectDifferences
}

<#
.Synopsis
    Provides MarkDown text for specific array of objects

.Description
    Returns a structured MarkDown string resolving objects

.Example
    Get-RelatedPolicy

.LINK
    https://maester.dev/docs/commands/Get-RelatedPolicy
#>
function Get-RelatedPolicy {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [System.Collections.ArrayList]$Arr,
        [String]$ObjName
    )
    $result = ''

    # Check each policy in the array
    foreach ($obj in $Arr) {
        # Check if the excluded object is present in the policy
        if ($obj.ExcludedObjects -contains $ObjName) {
            $result += "        > Excluded in policy '$($obj.PolicyName)'`n"
        }
    }

    return $result
}

<#
.Synopsis
    This function checks if all objects found in policy exclusions are found in policy inclusions.

.Description
    Checks for gaps in conditional access policies, by looking for excluded objects which are not specifically included
    in another conditional access policy. Instead of looking at the historical sign-ins to find gaps, we try to spot possibly
    overlooked exclusions which do not have a fallback.

.Example
    Test-MtCaGap

.LINK
    https://maester.dev/docs/commands/Test-MtCaGap
#>
function Test-MtCaGap {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $result = $false
    $testDescription = 'All excluded objects should have a fallback include in another policy'

    # Get the enabled conditional access policies
    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }
    Write-Verbose "Retrieved conditional access policies:`n $policies"

    # Variables related to users
    [System.Collections.ArrayList]$excludedUsers = @()
    [System.Collections.ArrayList]$includedUsers = @()
    [System.Collections.ArrayList]$differencesUsers = @()
    # Variables related to groups
    [System.Collections.ArrayList]$excludedGroups = @()
    [System.Collections.ArrayList]$includedGroups = @()
    [System.Collections.ArrayList]$differencesGroups = @()
    # Variables related to Roles
    [System.Collections.ArrayList]$excludedRoles = @()
    [System.Collections.ArrayList]$includedRoles = @()
    [System.Collections.ArrayList]$differencesRoles = @()
    # Variables related to Applications
    [System.Collections.ArrayList]$excludedApplications = @()
    [System.Collections.ArrayList]$includedApplications = @()
    [System.Collections.ArrayList]$differencesApplications = @()
    # Variables related to ServicePrincipals
    [System.Collections.ArrayList]$excludedServicePrincipals = @()
    [System.Collections.ArrayList]$includedServicePrincipals = @()
    [System.Collections.ArrayList]$differencesServicePrincipals = @()
    # Variables related to Locations
    [System.Collections.ArrayList]$excludedLocations = @()
    [System.Collections.ArrayList]$includedLocations = @()
    [System.Collections.ArrayList]$differencesLocations = @()
    # Variables related to Platforms
    [System.Collections.ArrayList]$excludedPlatforms = @()
    [System.Collections.ArrayList]$includedPlatforms = @()
    [System.Collections.ArrayList]$differencesPlatforms = @()
    # Mapping array
    [System.Collections.ArrayList]$mappingArray = @()

    try {
        # Get all the objects for all policies
        $policies | ForEach-Object {
            # Save all interesting objects for later use
            $_.Conditions.Users.ExcludeUsers | ForEach-Object { $excludedUsers.Add($_) | Out-Null }
            $_.Conditions.Users.IncludeUsers | ForEach-Object { $includedUsers.Add($_) | Out-Null }
            $_.Conditions.Users.ExcludeGroups | ForEach-Object { $excludedGroups.Add($_) | Out-Null }
            $_.Conditions.Users.IncludeGroups | ForEach-Object { $includedGroups.Add($_) | Out-Null }
            if ($_ -ne 'd29b2b05-8046-44ba-8758-1e26182fcf32') {
                # Role: 'Directory Synchronization Accounts' excluded
                # Policy: 'Multifactor authentication for Microsoft partners and vendors'
                $_.Conditions.Users.ExcludeRoles | ForEach-Object { $excludedRoles.Add($_) | Out-Null }
            }
            $_.Conditions.Users.IncludeRoles | ForEach-Object { $includedRoles.Add($_) | Out-Null }
            $_.Conditions.Applications.ExcludeApplications | ForEach-Object { $excludedApplications.Add($_) | Out-Null }
            $_.Conditions.Applications.IncludeApplications | ForEach-Object { $includedApplications.Add($_) | Out-Null }
            $_.Conditions.ClientApplications.ExcludeServicePrincipals | ForEach-Object { $excludedServicePrincipals.Add($_) | Out-Null }
            $_.Conditions.ClientApplications.IncludeServicePrincipals | ForEach-Object { $includedServicePrincipals.Add($_) | Out-Null }
            $_.Conditions.Locations.ExcludeLocations | ForEach-Object { $excludedLocations.Add($_) | Out-Null }
            $_.Conditions.Locations.IncludeLocations | ForEach-Object { $includedLocations.Add($_) | Out-Null }
            $_.Conditions.Platforms.ExcludePlatforms | ForEach-Object { $excludedPlatforms.Add($_) | Out-Null }
            $_.Conditions.Platforms.IncludePlatforms | ForEach-Object { $includedPlatforms.Add($_) | Out-Null }

            # Create a mapping for each policy with excluded objects
            [System.Collections.ArrayList]$allExcluded = $_.Conditions.Users.ExcludeUsers + `
                $_.Conditions.Users.ExcludeGroups + `
                $_.Conditions.Users.ExcludeRoles + `
                $_.Conditions.Applications.ExcludeApplications + `
                $_.Conditions.ClientApplications.ExcludeServicePrincipals + `
                $_.Conditions.Locations.ExcludeLocations + `
                $_.Conditions.Platforms.ExcludePlatforms
            # Create the mapping
            $mapping = [PSCustomObject]@{
                PolicyName      = $_.DisplayName
                ExcludedObjects = $allExcluded
            }
            # Add the mapping to the array and clear variable
            $mappingArray += $mapping
            Clear-Variable -Name allExcluded
        }
        Write-Verbose "Created a mapping with all excluded objects for each policy:`n $mapping"

        # Find which objects are excluded without a fallback
        [System.Collections.ArrayList]$differencesUsers = @(Get-ObjectDifference -excludedObjects $excludedUsers -includedObjects $includedUsers)
        [System.Collections.ArrayList]$differencesGroups = @(Get-ObjectDifference -excludedObjects $excludedGroups -includedObjects $includedGroups)
        [System.Collections.ArrayList]$differencesRoles = @(Get-ObjectDifference -excludedObjects $excludedRoles -includedObjects $includedRoles)
        [System.Collections.ArrayList]$differencesApplications = @(Get-ObjectDifference -excludedObjects $excludedApplications -includedObjects $includedApplications)
        [System.Collections.ArrayList]$differencesServicePrincipals = @(Get-ObjectDifference -excludedObjects $excludedServicePrincipals -includedObjects $includedServicePrincipals)
        [System.Collections.ArrayList]$differencesLocations = @(Get-ObjectDifference -excludedObjects $excludedLocations -includedObjects $includedLocations)
        [System.Collections.ArrayList]$differencesPlatforms = @(Get-ObjectDifference -excludedObjects $excludedPlatforms -includedObjects $includedPlatforms)
        Write-Verbose 'Finished searching for gaps in policies.'

        # Check if all excluded objects have fallbacks
        if (
            $differencesUsers.Count -eq 0 `
                -and $differencesGroups.Count -eq 0 `
                -and $differencesRoles.Count -eq 0 `
                -and $differencesApplications.Count -eq 0 `
                -and $differencesServicePrincipals.Count -eq 0 `
                -and $differencesLocations.Count -eq 0 `
                -and $differencesPlatforms.Count -eq 0 `
        ) {
            $result = $true
            $testResult = 'All excluded objects seem to have a fallback in other policies.'
            Write-Verbose 'All excluded objects seem to have a fallback in other policies.'
        } else {
            Write-Verbose 'Not all excluded objects seem to have a fallback in other policies.'
            # Add user objects to results
            if ($differencesUsers.Count -ne 0) {
                $testResult = "The following user objects did not have a fallback:`n`n"
                foreach ($Object in $differencesUsers) {
                    try {
                        $DisplayName = (Invoke-MtGraphRequest -RelativeUri 'users' -ApiVersion v1.0 -UniqueId $Object -ErrorAction Stop).displayName
                    } catch {
                        $DisplayName = "${Object} (Unable to resolve GUID)"
                    }
                    $testResult += "`n    User: ${DisplayName}`n"
                    $testResult += Get-RelatedPolicy -Arr $mappingArray -ObjName $Object
                }
            }
            # Add group objects to results
            if ($differencesGroups.Count -ne 0) {
                $testResult += "The following group objects did not have a fallback:`n`n"
                foreach ($Object in $differencesGroups) {
                    try {
                        $DisplayName = (Invoke-MtGraphRequest -RelativeUri 'groups' -ApiVersion v1.0 -UniqueId $Object -ErrorAction Stop).displayName
                    } catch {
                        $DisplayName = "${Object} (Unable to resolve GUID)"
                    }
                    $testResult += "`n    Group: ${DisplayName}`n"
                    $testResult += Get-RelatedPolicy -Arr $mappingArray -ObjName $Object
                }
            }
            # Add role objects to results
            if ($differencesRoles.Count -ne 0) {
                $testResult += "The following role objects did not have a fallback:`n`n"
                foreach ($Object in $differencesRoles) {
                    try {
                        $DisplayName = (Invoke-MtGraphRequest -RelativeUri 'directoryRoles' -ApiVersion v1.0 -UniqueId $Object -ErrorAction Stop).displayName
                    } catch {
                        $DisplayName = "${Object} (Unable to resolve GUID)"
                    }
                    $testResult += "`n    Role: ${DisplayName}`n"
                    $testResult += Get-RelatedPolicy -Arr $mappingArray -ObjName $_
                }
            }
            # Add application objects to results
            if ($differencesApplications.Count -ne 0) {
                $testResult += "The following application objects did not have a fallback:`n`n"
                foreach ($Object in $differencesApplications) {
                    try {
                        $DisplayName = (Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -ApiVersion v1.0 -Filter "appId eq '${Object}'" -ErrorAction Stop).displayName
                    } catch {
                        $DisplayName = "${Object} (Unable to resolve GUID)"
                    }
                    $testResult += "`n    Application: ${DisplayName}`n"
                    $testResult += Get-RelatedPolicy -Arr $mappingArray -ObjName $Object
                }
            }
            # Add service principal objects to results
            if ($differencesServicePrincipals.Count -ne 0) {
                $testResult += "The following service principal objects did not have a fallback:`n`n"
                foreach ($Object in $differencesServicePrincipals) {
                    try {
                        $DisplayName = (Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -ApiVersion v1.0 -UniqueId $Object -ErrorAction Stop).displayName
                    } catch {
                        $DisplayName = "${Object} (Unable to resolve GUID)"
                    }
                    $testResult += "`n    Service Principal: ${DisplayName}`n"
                    $testResult += Get-RelatedPolicy -Arr $mappingArray -ObjName $Object
                }
            }
            # Add location objects to results
            if ($differencesLocations.Count -ne 0) {
                $testResult += "The following location objects did not have a fallback:`n`n"
                foreach ($Object in $differencesLocations) {
                    try {
                        $DisplayName = (Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/namedLocations' -ApiVersion v1.0 -UniqueId $Object -ErrorAction Stop).displayName
                    } catch {
                        $DisplayName = "${Object} (Unable to resolve GUID)"
                    }
                    $testResult += "`n    Location: ${DisplayName}`n"
                    $testResult += Get-RelatedPolicy -Arr $mappingArray -ObjName $Object
                }
            }
            # Add platform objects to results
            if ($differencesPlatforms.Count -ne 0) {
                $testResult += "The following platform objects did not have a fallback:`n`n"
                foreach ($Object in $differencesPlatforms) {
                    $testResult += "`n    Platform: ${Object}`n"
                    $testResult += Get-RelatedPolicy -Arr $mappingArray -ObjName $Object
                }
            }
        }
        Add-MtTestResultDetail -Description $testDescription -Result $testResult

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
