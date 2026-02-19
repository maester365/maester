<#
.SYNOPSIS
    Checks if Entra ID Governance access packages or catalogs reference deleted groups

.DESCRIPTION
    MT.1107 - Access packages and catalogs should not reference deleted groups

    This test identifies access packages and catalogs in Microsoft Entra ID Governance
    that reference Entra ID groups which have been deleted. Deleted group references can cause:
    - Unexpected access provisioning failures
    - Configuration inconsistencies
    - Approval workflow issues
    - Compliance and audit concerns

    The test performs comprehensive checks across:
    - Access package resource assignments (groups assigned as resources)
    - Access package assignment policies (groups configured as approvers)
    - Access package catalog resources (groups registered in catalogs)

    For deleted groups still in the recycle bin, the test retrieves the actual group name
    to provide clear identification of which groups need attention.

    Learn more:
    https://maester.dev/docs/tests/MT.1107

.EXAMPLE
    Test-MtEntitlementManagementDeletedGroups

    Returns $true if all access packages and catalogs reference only active groups

.LINK
    https://maester.dev/docs/commands/Test-MtEntitlementManagementDeletedGroups
#>

function Test-MtEntitlementManagementDeletedGroups {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Groups is the resource type being tested')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        # Get all access packages
        $accessPackages = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackages" -ApiVersion beta

        # Check if access packages exist
        $packages = @()
        if ($accessPackages -is [Array]) {
            $packages = $accessPackages
        } elseif ($null -ne $accessPackages.value) {
            $packages = $accessPackages.value
        } elseif ($null -ne $accessPackages) {
            $packages = @($accessPackages)
        }

        if ($packages.Count -eq 0) {
            $testResult = "✅ No access packages found in the tenant."
            Add-MtTestResultDetail -Result $testResult
            return $true
        }

        $deletedGroupsFound = @()

        # Check each access package for deleted groups
        foreach ($package in $packages) {
            $packageId = if ($package.id) { $package.id } else { $package.PSObject.Properties['id'].Value }

            if ([string]::IsNullOrEmpty($packageId)) {
                Write-Verbose "Skipping package without ID: $($package.displayName)"
                continue
            }

            $packageName = if ($package.displayName) { $package.displayName } else { $package.PSObject.Properties['displayName'].Value }
            Write-Verbose "Checking access package: $packageName (ID: $packageId)"

            # Get access package assignment policies
            try {
                $policies = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackages/$packageId/assignmentPolicies" -ApiVersion beta

                $policyArray = @()
                if ($policies -is [Array]) {
                    $policyArray = $policies
                } elseif ($null -ne $policies.value) {
                    $policyArray = $policies.value
                } elseif ($null -ne $policies) {
                    $policyArray = @($policies)
                }

                foreach ($policy in $policyArray) {
                    if ($policy.requestApprovalSettings) {
                        foreach ($stage in $policy.requestApprovalSettings.approvalStages) {
                            if ($stage.primaryApprovers) {
                                foreach ($approver in $stage.primaryApprovers) {
                                    if ($approver.'@odata.type' -eq '#microsoft.graph.groupMembers') {
                                        $groupId = $approver.groupId

                                        # Try to get the group
                                        try {
                                            $group = Invoke-MtGraphRequest -RelativeUri "groups/$groupId" -ApiVersion beta -ErrorAction Stop
                                            if ($null -eq $group -or $null -eq $group.id) {
                                                $deletedGroupsFound += [PSCustomObject]@{
                                                    Type = "Access Package"
                                                    Name = $packageName
                                                    Id = $packageId
                                                    DeletedGroupId = $groupId
                                                    Context = "Approval Stage Primary Approver"
                                                }
                                            }
                                        } catch {
                                            $deletedGroupsFound += [PSCustomObject]@{
                                                Type = "Access Package"
                                                Name = $packageName
                                                Id = $packageId
                                                DeletedGroupId = $groupId
                                                Context = "Approval Stage Primary Approver"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                Write-Verbose "Could not retrieve assignment policies for access package: $packageName"
            }

            # Get access package resources (groups assigned through the package)
            try {
                $resources = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackages/$packageId/accessPackageResourceRoleScopes?`$expand=accessPackageResourceScope" -ApiVersion beta

                $resourceArray = @()
                if ($resources -is [Array]) {
                    $resourceArray = $resources
                } elseif ($null -ne $resources.value) {
                    $resourceArray = $resources.value
                } elseif ($null -ne $resources) {
                    $resourceArray = @($resources)
                }

                foreach ($resource in $resourceArray) {
                    $resourceScope = $resource.accessPackageResourceScope
                    $resourceType = if ($resourceScope.originSystem) { $resourceScope.originSystem } else { $resourceScope.PSObject.Properties['originSystem'].Value }
                    $groupId = if ($resourceScope.originId) { $resourceScope.originId } else { $resourceScope.PSObject.Properties['originId'].Value }
                    $resourceDisplayName = if ($resourceScope.displayName) { $resourceScope.displayName } else { $resourceScope.PSObject.Properties['displayName'].Value }

                    if ($resourceType -eq 'AadGroup' -and $groupId) {
                        $groupStillExists = $false
                        $actualGroupName = $resourceDisplayName

                        try {
                            $group = Invoke-MtGraphRequest -RelativeUri "groups/$groupId" -ApiVersion beta -ErrorAction Stop
                            if ($group -and $group.id) {
                                $groupStillExists = $true
                            }
                        } catch {
                            # Try to get from deleted items
                            try {
                                $deletedGroup = Invoke-MtGraphRequest -RelativeUri "directory/deletedItems/$groupId" -ApiVersion beta -ErrorAction Stop
                                if ($deletedGroup -and $deletedGroup.displayName) {
                                    $actualGroupName = $deletedGroup.displayName
                                }
                            } catch {
                                Write-Verbose "Could not retrieve deleted group name for $groupId"
                            }
                        }

                        if (-not $groupStillExists) {
                            $deletedGroupsFound += [PSCustomObject]@{
                                Type = "Access Package"
                                Name = $packageName
                                Id = $packageId
                                DeletedGroupId = $groupId
                                Context = "Resource Assignment"
                                ResourceDisplayName = $actualGroupName
                            }
                        }
                    }
                }
            } catch {
                Write-Verbose "Could not retrieve resources for access package: $packageName"
            }
        }

        # Check access package catalogs for deleted groups
        try {
            $catalogs = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackageCatalogs" -ApiVersion beta

            $catalogArray = @()
            if ($catalogs -is [Array]) {
                $catalogArray = $catalogs
            } elseif ($null -ne $catalogs.value) {
                $catalogArray = $catalogs.value
            } elseif ($null -ne $catalogs) {
                $catalogArray = @($catalogs)
            }

            foreach ($catalog in $catalogArray) {
                Write-Verbose "Checking catalog: $($catalog.displayName)"

                try {
                    $resources = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackageCatalogs/$($catalog.id)/accessPackageResources" -ApiVersion beta

                    $resourceArray = @()
                    if ($resources -is [Array]) {
                        $resourceArray = $resources
                    } elseif ($null -ne $resources.value) {
                        $resourceArray = $resources.value
                    } elseif ($null -ne $resources) {
                        $resourceArray = @($resources)
                    }

                    foreach ($resource in $resourceArray) {
                        if ($resource.resourceType -eq 'AadGroup' -or $resource.originSystem -eq 'AadGroup') {
                            $groupId = $resource.originId
                            $actualGroupName = $resource.displayName

                            $groupStillExists = $false
                            try {
                                $group = Invoke-MtGraphRequest -RelativeUri "groups/$groupId" -ApiVersion beta -ErrorAction Stop
                                if ($group -and $group.id) {
                                    $groupStillExists = $true
                                }
                            } catch {
                                try {
                                    $deletedGroup = Invoke-MtGraphRequest -RelativeUri "directory/deletedItems/$groupId" -ApiVersion beta -ErrorAction Stop
                                    if ($deletedGroup -and $deletedGroup.displayName) {
                                        $actualGroupName = $deletedGroup.displayName
                                    }
                                } catch {
                                    Write-Verbose "Could not retrieve deleted group name for $groupId in catalog"
                                }
                            }

                            if (-not $groupStillExists) {
                                $deletedGroupsFound += [PSCustomObject]@{
                                    Type = "Catalog"
                                    Name = $catalog.displayName
                                    Id = $catalog.id
                                    DeletedGroupId = $groupId
                                    Context = "Catalog Resource"
                                    ResourceDisplayName = $actualGroupName
                                }
                            }
                        }
                    }
                } catch {
                    Write-Verbose "Could not retrieve resources for catalog: $($catalog.displayName)"
                }
            }
        } catch {
            Write-Verbose "Could not retrieve access package catalogs: $_"
        }

        # Evaluate results
        $result = $deletedGroupsFound.Count -eq 0

        if ($result) {
            $testResult = "✅ All access packages and catalogs reference only active groups."
            Add-MtTestResultDetail -Result $testResult
        } else {
            $accessPackageIssues = $deletedGroupsFound | Where-Object { $_.Type -eq "Access Package" }
            $catalogIssues = $deletedGroupsFound | Where-Object { $_.Type -eq "Catalog" }

            $realIssuesCount = $accessPackageIssues.Count + $catalogIssues.Count

            $testResult = "❌ Found $realIssuesCount reference(s) to deleted groups:`n`n"

            $issuesByGroup = $deletedGroupsFound | Group-Object DeletedGroupId

            foreach ($grouping in $issuesByGroup) {
                $deletedGroupId = $grouping.Name
                $groupDisplayName = ($grouping.Group | Select-Object -First 1).ResourceDisplayName
                if ([string]::IsNullOrEmpty($groupDisplayName)) {
                    $groupDisplayName = "Unknown Group"
                }

                $testResult += "### Deleted Group: **$groupDisplayName**`n"
                $testResult += "Group ID: ``$deletedGroupId```n`n"

                $catalogsForGroup = $grouping.Group | Where-Object { $_.Type -eq "Catalog" }
                $packagesForGroup = $grouping.Group | Where-Object { $_.Type -eq "Access Package" }

                if ($catalogsForGroup.Count -gt 0) {
                    $testResult += "**Referenced in Catalog(s):**`n"
                    foreach ($item in $catalogsForGroup) {
                        $testResult += "- [$($item.Name)](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin/CatalogBlade/catalogId/$($item.Id))`n"
                    }
                    $testResult += "`n"
                }

                if ($packagesForGroup.Count -gt 0) {
                    $testResult += "**Referenced in Access Package(s):**`n"
                    foreach ($item in $packagesForGroup) {
                        $testResult += "- [$($item.Name)](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin/EntitlementMenuBlade/~/overview/entitlementId/$($item.Id))`n"
                    }
                    $testResult += "`n"
                }
            }

            $testResult += "---`n**Remediation:** Review and update access packages and catalogs to remove references to deleted groups, or restore the groups if needed.`n"

            Add-MtTestResultDetail -Result $testResult
        }

        return $result

    } catch {
        Write-Error "Error checking access packages and catalogs: $($_.Exception.Message)"
        return $false
    }
}


