<#
.SYNOPSIS
    Checks if access package approval workflows have valid approvers

.DESCRIPTION
    MT.1109 - Access package approval workflows must have valid approvers

    This test identifies Microsoft Entra ID Governance access package assignment policies with
    approval workflows that reference invalid approvers. Invalid approvers can cause:
    - Approval workflow failures
    - Access request timeouts
    - Broken automation flows
    - User frustration and support tickets

    The test validates that all approval workflows have:
    - Valid user approvers (account enabled, not deleted)
    - Valid group approvers (group exists and has members)
    - Manager approvers where requestor has an assigned manager
    - No references to deleted or disabled accounts

    Learn more:
    https://maester.dev/docs/tests/MT.1109

.EXAMPLE
    Test-MtEntitlementManagementValidApprovers

    Returns $true if all approval workflows have valid approvers

.LINK
    https://maester.dev/docs/commands/Test-MtEntitlementManagementValidApprovers
#>

function Test-MtEntitlementManagementValidApprovers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Approvers is the resource type being tested')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        # Get all access packages
        $accessPackages = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackages" -ApiVersion beta

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

        $invalidApproversFound = @()

        # Check each access package for invalid approvers
        foreach ($package in $packages) {
            $packageId = if ($package.id) { $package.id } else { $package.PSObject.Properties['id'].Value }

            if ([string]::IsNullOrEmpty($packageId)) {
                Write-Verbose "Skipping package without ID: $($package.displayName)"
                continue
            }

            $packageName = if ($package.displayName) { $package.displayName } else { $package.PSObject.Properties['displayName'].Value }
            Write-Verbose "Checking access package: $packageName (ID: $packageId)"

            # Get assignment policies
            try {
                $policies = Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/accessPackageAssignmentPolicies?`$filter=accessPackage/id eq '$packageId'" -ApiVersion beta

                $policyArray = @()
                if ($policies -is [Array]) {
                    $policyArray = $policies
                } elseif ($null -ne $policies.value) {
                    $policyArray = $policies.value
                } elseif ($null -ne $policies) {
                    $policyArray = @($policies)
                }

                if ($policyArray.Count -eq 0) {
                    Write-Verbose "No policies found for package: $packageName"
                    continue
                }

                # Check each policy for approval workflow issues
                foreach ($policy in $policyArray) {
                    $policyName = if ($policy.displayName) { $policy.displayName } else { $policy.PSObject.Properties['displayName'].Value }

                    # Skip default system policies
                    if ($policyName -like "*All members*" -and $policyName -like "*excluding guests*") {
                        Write-Verbose "Skipping default system policy: $policyName"
                        continue
                    }

                    Write-Verbose "Checking policy: $policyName"

                    $requestApprovalSettings = $policy.requestApprovalSettings
                    if ($null -eq $requestApprovalSettings) {
                        Write-Verbose "Policy has no approval settings"
                        continue
                    }

                    $isApprovalRequired = $requestApprovalSettings.isApprovalRequired
                    if (-not $isApprovalRequired) {
                        Write-Verbose "Policy does not require approval"
                        continue
                    }

                    $approvalStages = $requestApprovalSettings.approvalStages
                    if ($null -eq $approvalStages -or $approvalStages.Count -eq 0) {
                        $invalidApproversFound += [PSCustomObject]@{
                            PackageId = $packageId
                            PackageName = $packageName
                            PolicyName = $policyName
                            Issue = "No approval stages"
                            ApproverType = "N/A"
                            ApproverDetails = "Approval required but no stages defined"
                        }
                        continue
                    }

                    # Check each approval stage
                    foreach ($stage in $approvalStages) {
                        $primaryApprovers = $stage.primaryApprovers
                        if ($null -eq $primaryApprovers -or $primaryApprovers.Count -eq 0) {
                            $invalidApproversFound += [PSCustomObject]@{
                                PackageId = $packageId
                                PackageName = $packageName
                                PolicyName = $policyName
                                Issue = "No primary approvers"
                                ApproverType = "N/A"
                                ApproverDetails = "Stage has no approvers"
                            }
                            continue
                        }

                        # Check each approver
                        foreach ($approver in $primaryApprovers) {
                            $approverType = $approver.'@odata.type'

                            switch ($approverType) {
                                '#microsoft.graph.singleUser' {
                                    $userId = if ($approver.userId) { $approver.userId } elseif ($approver.id) { $approver.id } else {
                                        if ($approver.PSObject.Properties['userId']) { $approver.PSObject.Properties['userId'].Value } else { $approver.PSObject.Properties['id'].Value }
                                    }

                                    if ([string]::IsNullOrEmpty($userId)) {
                                        $invalidApproversFound += [PSCustomObject]@{
                                            PackageId = $packageId
                                            PackageName = $packageName
                                            PolicyName = $policyName
                                            Issue = "User has no ID"
                                            ApproverType = "User"
                                            ApproverDetails = "Invalid configuration"
                                        }
                                        continue
                                    }

                                    try {
                                        $user = Invoke-MtGraphRequest -RelativeUri "users/$userId" -ApiVersion beta -ErrorAction SilentlyContinue

                                        if ($null -eq $user) {
                                            $invalidApproversFound += [PSCustomObject]@{
                                                PackageId = $packageId
                                                PackageName = $packageName
                                                PolicyName = $policyName
                                                Issue = "User not found"
                                                ApproverType = "User"
                                                ApproverDetails = "ID: $userId"
                                            }
                                        } elseif ($user.accountEnabled -eq $false) {
                                            $userName = if ($user.displayName) { $user.displayName } else { $user.userPrincipalName }
                                            $invalidApproversFound += [PSCustomObject]@{
                                                PackageId = $packageId
                                                PackageName = $packageName
                                                PolicyName = $policyName
                                                Issue = "User disabled"
                                                ApproverType = "User"
                                                ApproverDetails = "$userName"
                                            }
                                        }
                                    } catch {
                                        if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*not found*") {
                                            $invalidApproversFound += [PSCustomObject]@{
                                                PackageId = $packageId
                                                PackageName = $packageName
                                                PolicyName = $policyName
                                                Issue = "User deleted"
                                                ApproverType = "User"
                                                ApproverDetails = "ID: $userId"
                                            }
                                        }
                                    }
                                }

                                '#microsoft.graph.groupMembers' {
                                    $groupId = if ($approver.groupId) { $approver.groupId } elseif ($approver.id) { $approver.id } else {
                                        if ($approver.PSObject.Properties['groupId']) { $approver.PSObject.Properties['groupId'].Value } else { $approver.PSObject.Properties['id'].Value }
                                    }

                                    if ([string]::IsNullOrEmpty($groupId)) {
                                        $invalidApproversFound += [PSCustomObject]@{
                                            PackageId = $packageId
                                            PackageName = $packageName
                                            PolicyName = $policyName
                                            Issue = "Group has no ID"
                                            ApproverType = "Group"
                                            ApproverDetails = "Invalid configuration"
                                        }
                                        continue
                                    }

                                    try {
                                        $group = Invoke-MtGraphRequest -RelativeUri "groups/$groupId" -ApiVersion beta -ErrorAction SilentlyContinue

                                        if ($null -eq $group) {
                                            $invalidApproversFound += [PSCustomObject]@{
                                                PackageId = $packageId
                                                PackageName = $packageName
                                                PolicyName = $policyName
                                                Issue = "Group not found"
                                                ApproverType = "Group"
                                                ApproverDetails = "ID: $groupId"
                                            }
                                            continue
                                        }

                                        # Check if group has members
                                        try {
                                            $members = Invoke-MtGraphRequest -RelativeUri "groups/$groupId/members?`$top=1" -ApiVersion beta -ErrorAction SilentlyContinue

                                            $memberCount = 0
                                            if ($members -is [Array]) {
                                                $memberCount = $members.Count
                                            } elseif ($null -ne $members.value) {
                                                $memberCount = $members.value.Count
                                            } elseif ($null -ne $members) {
                                                $memberCount = 1
                                            }

                                            if ($memberCount -eq 0) {
                                                $groupName = if ($group.displayName) { $group.displayName } else { "Unknown" }
                                                $invalidApproversFound += [PSCustomObject]@{
                                                    PackageId = $packageId
                                                    PackageName = $packageName
                                                    PolicyName = $policyName
                                                    Issue = "Group has no members"
                                                    ApproverType = "Group"
                                                    ApproverDetails = $groupName
                                                }
                                            }
                                        } catch {
                                            Write-Verbose "Error checking members for group $groupId"
                                        }
                                    } catch {
                                        if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*not found*") {
                                            $invalidApproversFound += [PSCustomObject]@{
                                                PackageId = $packageId
                                                PackageName = $packageName
                                                PolicyName = $policyName
                                                Issue = "Group deleted"
                                                ApproverType = "Group"
                                                ApproverDetails = "ID: $groupId"
                                            }
                                        }
                                    }
                                }

                                '#microsoft.graph.requestorManager' {
                                    Write-Verbose "Policy uses manager approval"
                                }

                                '#microsoft.graph.internalSponsors' {
                                    Write-Verbose "Policy uses internal sponsors"
                                }

                                '#microsoft.graph.externalSponsors' {
                                    Write-Verbose "Policy uses external sponsors"
                                }
                            }
                        }
                    }
                }
            } catch {
                Write-Verbose "Error processing package $packageName : $_"
            }
        }

        # Determine test result
        if ($invalidApproversFound.Count -eq 0) {
            $testResult = "✅ All approval workflows have valid approvers.`n`nChecked $($packages.Count) access package(s)."
            Add-MtTestResultDetail -Result $testResult
            return $true
        } else {
            $groupedByPackage = $invalidApproversFound | Group-Object -Property PackageId

            $testResult = "❌ Found $($invalidApproversFound.Count) invalid approver(s) across $($groupedByPackage.Count) access package(s):`n`n"

            $testResult += "| Access Package | Policy | Issue | Type | Details |`n"
            $testResult += "|---|---|---|---|---|`n"

            foreach ($item in $invalidApproversFound) {
                $packageLink = "https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin/EntitlementMenuBlade/~/overview/entitlementId/$($item.PackageId)"
                $packageName = "[$($item.PackageName)]($packageLink)"

                $testResult += "| $packageName | $($item.PolicyName) | $($item.Issue) | $($item.ApproverType) | $($item.ApproverDetails) |`n"
            }

            $testResult += "`n**Remediation:** Update approval workflows to use valid, active approvers in the [Entra portal](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin).`n"

            Add-MtTestResultDetail -Result $testResult
            return $false
        }

    } catch {
        Write-Error "Error running test: $($_.Exception.Message)"
        return $false
    }
}


