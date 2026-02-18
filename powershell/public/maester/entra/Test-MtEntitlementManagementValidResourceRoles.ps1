<#
.SYNOPSIS
    Validates catalog resources have no stale app roles or deleted service principals

.DESCRIPTION
    MT.1106 - Catalog resources must have valid roles (no stale / removed app roles or SPNs)

    This test identifies Entra ID Governance access package catalog resources that
    reference deleted service principals, stale app roles, or inaccessible SharePoint sites.

    When Enterprise Applications are deleted or reconfigured (app roles removed), or when
    SharePoint sites are deleted/moved, catalogs often retain references that cause
    provisioning failures when users request access.

    The test validates:
    - Application resources point to existing service principals
    - App roles assigned in access packages still exist in service principals
    - SharePoint sites are accessible via Graph API
    - "Default Access" roles are excluded (system defaults)

    Issues detected:
    - Deleted service principals (404 errors)
    - Stale app roles removed from service principal but still in access packages
    - Deleted or inaccessible SharePoint sites
    - Invalid SharePoint URLs

    Note: Group validation is delegated to MT.1107 for comprehensive coverage.

    Learn more:
    https://maester.dev/docs/tests/MT.1106

.EXAMPLE
    Test-MtEntitlementManagementValidResourceRoles

    Returns $true if all catalog resources have valid roles and service principals

.LINK
    https://maester.dev/docs/commands/Test-MtEntitlementManagementValidResourceRoles
#>

function Test-MtEntitlementManagementValidResourceRoles {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Roles is the resource type being tested')]
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
            $testResult = "✅ No catalogs found in the tenant."
            Add-MtTestResultDetail -Result $testResult
            return $true
        }

        Write-Verbose "Found $($catalogArray.Count) catalog(s) to check"

        $staleResourcesFound = @()

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

        Write-Verbose "Found $($allPackageArray.Count) access package(s) to check"

        # Check each catalog for stale resources
        foreach ($catalog in $catalogArray) {
            $catalogId = if ($catalog.id) { $catalog.id } else { $catalog.PSObject.Properties['id'].Value }
            $catalogName = if ($catalog.displayName) { $catalog.displayName } else { $catalog.PSObject.Properties['displayName'].Value }

            if ([string]::IsNullOrEmpty($catalogId)) {
                Write-Verbose "Skipping catalog without ID"
                continue
            }

            Write-Verbose "Checking catalog: $catalogName (ID: $catalogId)"

            try {
                # Get all resources in this catalog
                $resources = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackageCatalogs/$catalogId/accessPackageResources" -ApiVersion beta

                $resourceArray = @()
                if ($resources -is [Array]) {
                    $resourceArray = $resources
                } elseif ($null -ne $resources.value) {
                    $resourceArray = $resources.value
                } elseif ($null -ne $resources) {
                    $resourceArray = @($resources)
                }

                Write-Verbose "Catalog '$catalogName' has $($resourceArray.Count) resource(s)"

                if ($resourceArray.Count -eq 0) {
                    continue
                }

                # Check each resource
                foreach ($resource in $resourceArray) {
                    $resourceOriginId = if ($resource.originId) { $resource.originId } else { $resource.PSObject.Properties['originId'].Value }
                    $resourceDisplayName = if ($resource.displayName) { $resource.displayName } else { $resource.PSObject.Properties['displayName'].Value }
                    $resourceType = if ($resource.resourceType) { $resource.resourceType } elseif ($resource.originSystem) { $resource.originSystem } else { "Unknown" }

                    if ([string]::IsNullOrEmpty($resourceOriginId)) {
                        $staleResourcesFound += [PSCustomObject]@{
                            CatalogId = $catalogId
                            CatalogName = $catalogName
                            ResourceName = $resourceDisplayName
                            ResourceType = $resourceType
                            Issue = "Missing origin ID"
                        }
                        continue
                    }

                    Write-Verbose "Validating resource: $resourceDisplayName (Type: $resourceType)"

                    $validationFailed = $false
                    $issueDescription = ""

                    switch -Wildcard ($resourceType) {
                        "*Group*" {
                            Write-Verbose "Skipping group resource (covered by MT.1107)"
                            continue
                        }

                        "Built-in" {
                            Write-Verbose "Skipping built-in role resource"
                            continue
                        }

                        "*Application*" {
                            # Check if service principal exists
                            try {
                                $sp = Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$resourceOriginId" -ApiVersion beta -ErrorAction Stop

                                if (-not $sp -or -not $sp.id) {
                                    $validationFailed = $true
                                    $issueDescription = "Service principal not found"
                                } else {
                                    Write-Verbose "Service principal exists: $($sp.displayName)"

                                    # Check for stale app roles using cached packages
                                        $catalogPackages = $allPackageArray | Where-Object { $_.catalogId -eq $catalogId }

                                        foreach ($package in $catalogPackages) {
                                            try {
                                                $roleScopes = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackages/$($package.id)/accessPackageResourceRoleScopes?`$expand=accessPackageResourceRole,accessPackageResourceScope" -ApiVersion beta

                                                $roleScopeArray = @()
                                                if ($roleScopes -is [Array]) {
                                                    $roleScopeArray = $roleScopes
                                                } elseif ($null -ne $roleScopes.value) {
                                                    $roleScopeArray = $roleScopes.value
                                                } elseif ($null -ne $roleScopes) {
                                                    $roleScopeArray = @($roleScopes)
                                                }

                                                foreach ($roleScope in $roleScopeArray) {
                                                    $resScope = $roleScope.accessPackageResourceScope
                                                    $resRole = $roleScope.accessPackageResourceRole

                                                    if ($resScope.originId -eq $resourceOriginId) {
                                                        $roleOriginId = $resRole.originId
                                                        $roleDisplayName = $resRole.displayName

                                                        if ($roleDisplayName -eq "Default Access") {
                                                            continue
                                                        }

                                                        $spAppRoleIds = @()
                                                        if ($sp.appRoles) {
                                                            $spAppRoleIds = $sp.appRoles | ForEach-Object { $_.id }
                                                        }

                                                        if ($roleOriginId -and $roleOriginId -ne "00000000-0000-0000-0000-000000000000") {
                                                            if ($spAppRoleIds -notcontains $roleOriginId) {
                                                                $validationFailed = $true
                                                                $issueDescription = "App role '$roleDisplayName' no longer exists"
                                                                $resourceType = "App Role"
                                                                break
                                                            }
                                                        }
                                                    }
                                                }
                                            } catch {
                                                Write-Verbose "Could not retrieve role scopes for package"
                                            }

                                            if ($validationFailed) {
                                                break
                                            }
                                        }
                                }
                            } catch {
                                $validationFailed = $true
                                $issueDescription = "Service principal deleted or inaccessible"
                            }
                        }

                        "*SharePoint*" {
                            # Check if SharePoint site exists
                            try {
                                if ($resourceOriginId -match "^https://") {
                                    $siteUrl = $resourceOriginId
                                    Write-Verbose "Validating SharePoint site: $siteUrl"

                                    if ($siteUrl -match '^https://([^/]+)(.*)$') {
                                        $hostname = $Matches[1]
                                        $sitePath = $Matches[2]
                                        $siteIdentifier = "${hostname}:${sitePath}"

                                        try {
                                            $site = Invoke-MtGraphRequest -RelativeUri "sites/$siteIdentifier" -ApiVersion v1.0

                                            if (-not $site) {
                                                $validationFailed = $true
                                                $issueDescription = "SharePoint site not accessible"
                                                $resourceType = "SharePoint Site"
                                            }
                                        } catch {
                                            $validationFailed = $true
                                            $issueDescription = "SharePoint site not accessible"
                                            $resourceType = "SharePoint Site"
                                        }
                                    } else {
                                        Write-Verbose "Could not parse SharePoint URL"
                                    }
                                } else {
                                    $validationFailed = $true
                                    $issueDescription = "Invalid URL format"
                                    $resourceType = "SharePoint Site"
                                }
                            } catch {
                                Write-Verbose "Error validating SharePoint site"
                            }
                        }

                        "*Site*" {
                            if ($resourceOriginId -notmatch "^https://") {
                                $validationFailed = $true
                                $issueDescription = "Invalid URL format"
                            }
                        }
                    }

                    if ($validationFailed) {
                        Write-Verbose "Found stale resource: $resourceDisplayName - $issueDescription"

                        $staleResourcesFound += [PSCustomObject]@{
                            CatalogId = $catalogId
                            CatalogName = $catalogName
                            ResourceName = $resourceDisplayName
                            ResourceType = $resourceType
                            Issue = $issueDescription
                        }
                    }
                }
            } catch {
                Write-Verbose "Error processing catalog '$catalogName': $_"
            }
        }

        # Determine test result
        if ($staleResourcesFound.Count -eq 0) {
            $testResult = "✅ All application and SharePoint resources have valid roles and service principals.`n`nChecked $($catalogArray.Count) catalog(s).`n`n*Note: Group validation is covered by MT.1107*"
            Add-MtTestResultDetail -Result $testResult
            return $true
        } else {
            $testResult = "❌ Found $($staleResourcesFound.Count) stale resource(s):`n`n"

            $testResult += "| Catalog | Resource Name | Type | Issue |`n"
            $testResult += "|---|---|---|---|`n"

            foreach ($item in $staleResourcesFound) {
                $friendlyType = switch -Wildcard ($item.ResourceType) {
                    "*Application*" { "Application" }
                    "*SharePoint*" { "SharePoint Site" }
                    "*Site*" { "Site" }
                    default { $item.ResourceType }
                }

                $catalogLink = "https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin/CatalogBlade/catalogId/$($item.CatalogId)"
                $catalogCell = "[$($item.CatalogName)]($catalogLink)"

                $testResult += "| $catalogCell | $($item.ResourceName) | $friendlyType | $($item.Issue) |`n"
            }

            $testResult += "`n**Remediation:** Remove stale resources from catalogs or restore the underlying service principals/sites.`n"

            Add-MtTestResultDetail -Result $testResult
            return $false
        }

    } catch {
        Write-Error "Error running test: $($_.Exception.Message)"
        return $false
    }
}


