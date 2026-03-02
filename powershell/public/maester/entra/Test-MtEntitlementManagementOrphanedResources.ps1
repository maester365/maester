<#
.SYNOPSIS
    Checks if catalogs contain unused resources without associated access packages

.DESCRIPTION
    MT.1110 - No catalog should contain resources without any associated access packages

    This test identifies Microsoft Entra ID Governance access package catalogs that contain
    resources (groups, applications, SharePoint sites) that are not used in any access package.

    Unused catalog resources can indicate:
    - Resources added but never configured in packages
    - Leftover resources from deleted or modified access packages
    - Configuration drift or incomplete setup
    - Potential security and governance gaps
    - Wasted administrative effort maintaining unused resources

    The test validates that:
    - All catalog resources are used in at least one access package
    - Resources are properly linked to package role scopes
    - No orphaned resources exist in catalogs
    - Catalog resources serve their intended purpose

    Learn more:
    https://maester.dev/docs/tests/MT.1110

.EXAMPLE
    Test-MtEntitlementManagementOrphanedResources

    Returns $true if all catalog resources are used in access packages

.LINK
    https://maester.dev/docs/commands/Test-MtEntitlementManagementOrphanedResources
#>

function Test-MtEntitlementManagementOrphanedResources {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Resources is the resource type being tested')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        # Get all access package catalogs
        $catalogs = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackageCatalogs" -ApiVersion beta

        $catalogArray = @()
        if ($catalogs -is [Array]) {
            $catalogArray = $catalogs
        } elseif ($null -ne $catalogs.value) {
            $catalogArray = $catalogs.value
        } elseif ($null -ne $catalogs) {
            $catalogArray = @($catalogs)
        }

        if ($catalogArray.Count -eq 0) {
            $testResult = "✅ No access package catalogs found in the tenant."
            Add-MtTestResultDetail -Result $testResult
            return $true
        }

        $unusedResourcesFound = @()

        # Get all access packages once (cache for performance)
        $allPackages = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackages" -ApiVersion beta

        $allPackageArray = @()
        if ($allPackages -is [Array]) {
            $allPackageArray = $allPackages
        } elseif ($null -ne $allPackages.value) {
            $allPackageArray = $allPackages.value
        } elseif ($null -ne $allPackages) {
            $allPackageArray = @($allPackages)
        }

        Write-Verbose "Found $($allPackageArray.Count) access package(s) total"

        # Check each catalog for unused resources
        foreach ($catalog in $catalogArray) {
            $catalogId = if ($catalog.id) { $catalog.id } else { $catalog.PSObject.Properties['id'].Value }

            if ([string]::IsNullOrEmpty($catalogId)) {
                Write-Verbose "Skipping catalog without ID"
                continue
            }

            $catalogName = if ($catalog.displayName) { $catalog.displayName } else { $catalog.PSObject.Properties['displayName'].Value }
            Write-Verbose "Checking catalog: $catalogName (ID: $catalogId)"

            # Get all resources in this catalog
            try {
                $catalogResources = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackageCatalogs/$catalogId/accessPackageResources" -ApiVersion beta

                $resourceArray = @()
                if ($catalogResources -is [Array]) {
                    $resourceArray = $catalogResources
                } elseif ($null -ne $catalogResources.value) {
                    $resourceArray = $catalogResources.value
                } elseif ($null -ne $catalogResources) {
                    $resourceArray = @($catalogResources)
                }

                if ($resourceArray.Count -eq 0) {
                    Write-Verbose "Catalog '$catalogName' has no resources"
                    continue
                }

                Write-Verbose "Catalog '$catalogName' has $($resourceArray.Count) resource(s)"

                # Filter cached packages to only those in this catalog
                $packageArray = @($allPackageArray | Where-Object {
                    $pkgCatalogId = if ($_.catalogId) { $_.catalogId } else { $_.PSObject.Properties['catalogId'].Value }
                    $pkgCatalogId -eq $catalogId
                })

                Write-Verbose "Catalog '$catalogName' has $($packageArray.Count) access package(s)"

                # Skip catalogs with no access packages
                if ($packageArray.Count -eq 0) {
                    Write-Verbose "Skipping catalog '$catalogName' - no access packages configured"
                    continue
                }

                # Build a set of resource IDs that are used in access packages
                $usedResourceIds = @{}

                foreach ($package in $packageArray) {
                    $packageId = if ($package.id) { $package.id } else { $package.PSObject.Properties['id'].Value }

                    if ([string]::IsNullOrEmpty($packageId)) {
                        continue
                    }

                    # Get resource role scopes for this package
                    try {
                        $resourceRoleScopes = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackages/$packageId/accessPackageResourceRoleScopes?`$expand=accessPackageResourceRole,accessPackageResourceScope" -ApiVersion beta

                        $roleScopeArray = @()
                        if ($resourceRoleScopes -is [Array]) {
                            $roleScopeArray = $resourceRoleScopes
                        } elseif ($null -ne $resourceRoleScopes.value) {
                            $roleScopeArray = $resourceRoleScopes.value
                        } elseif ($null -ne $resourceRoleScopes) {
                            $roleScopeArray = @($resourceRoleScopes)
                        }

                        foreach ($roleScope in $roleScopeArray) {
                            $resourceId = $null

                            if ($roleScope.accessPackageResourceScope) {
                                $scope = $roleScope.accessPackageResourceScope
                                $resourceId = if ($scope.originId) { $scope.originId } else { $scope.PSObject.Properties['originId'].Value }
                            }

                            if (-not [string]::IsNullOrEmpty($resourceId)) {
                                $usedResourceIds[$resourceId] = $true
                            }
                        }
                    } catch {
                        Write-Verbose "Error getting resource role scopes for package $packageId : $_"
                    }
                }

                Write-Verbose "Found $($usedResourceIds.Count) unique resource(s) used in access packages"

                # Check each catalog resource to see if it's used
                foreach ($resource in $resourceArray) {
                    $resourceOriginId = if ($resource.originId) { $resource.originId } else { $resource.PSObject.Properties['originId'].Value }

                    if ([string]::IsNullOrEmpty($resourceOriginId)) {
                        Write-Verbose "Skipping resource without originId"
                        continue
                    }

                    # Check if this resource is used in any access package
                    if (-not $usedResourceIds.ContainsKey($resourceOriginId)) {
                        $resourceDisplayName = if ($resource.displayName) { $resource.displayName } else {
                            if ($resource.PSObject.Properties['displayName']) { $resource.PSObject.Properties['displayName'].Value } else { "Unknown Resource" }
                        }

                        $resourceType = if ($resource.resourceType) { $resource.resourceType }
                        elseif ($resource.originSystem) { $resource.originSystem }
                        else { "Unknown" }

                        Write-Verbose "Found unused resource: $resourceDisplayName (ID: $resourceOriginId, Type: $resourceType)"

                        $unusedResourcesFound += [PSCustomObject]@{
                            CatalogId = $catalogId
                            CatalogName = $catalogName
                            ResourceId = $resourceOriginId
                            ResourceName = $resourceDisplayName
                            ResourceType = $resourceType
                        }
                    }
                }
            } catch {
                Write-Verbose "Error processing catalog '$catalogName': $_"
            }
        }

        # Determine test result
        if ($unusedResourcesFound.Count -eq 0) {
            $testResult = "✅ All catalog resources are used in access packages.`n`nChecked $($catalogArray.Count) catalog(s)."
            Add-MtTestResultDetail -Result $testResult
            return $true
        } else {
            $groupedByCatalog = $unusedResourcesFound | Group-Object -Property CatalogId

            $testResult = "❌ Found $($unusedResourcesFound.Count) unused resource(s) across $($groupedByCatalog.Count) catalog(s):`n`n"

            $testResult += "| Catalog | Resource Name | Type |`n"
            $testResult += "|---|---|---|`n"

            foreach ($item in $unusedResourcesFound) {
                $catalogLink = "https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin/CatalogBlade/catalogId/$($item.CatalogId)"
                $catalogCell = "[$($item.CatalogName)]($catalogLink)"

                $friendlyType = switch -Wildcard ($item.ResourceType) {
                    "*Group*" { "Group" }
                    "*Application*" { "Application" }
                    "*SharePoint*" { "SharePoint Site" }
                    "*Site*" { "SharePoint Site" }
                    default { $item.ResourceType }
                }

                $testResult += "| $catalogCell | $($item.ResourceName) | $friendlyType |`n"
            }

            $testResult += "`n**Remediation:** Review unused resources and either add them to an access package or remove them from the catalog.`n"

            Add-MtTestResultDetail -Result $testResult
            return $false
        }

    } catch {
        Write-Error "Error running test: $($_.Exception.Message)"
        return $false
    }
}


