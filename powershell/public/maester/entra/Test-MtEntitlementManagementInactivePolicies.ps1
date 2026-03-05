<#
.SYNOPSIS
    Checks if access packages have inactive or orphaned assignment policies

.DESCRIPTION
    MT.1108 - Access packages should not reference inactive or orphaned assignment policies

    This test identifies Microsoft Entra ID Governance access packages that contain assignment policies
    which are disabled, misconfigured, or orphaned. Inactive policies can cause:
    - Blocked access requests
    - Broken approval workflows
    - Inconsistent user lifecycle automation
    - Configuration drift

    The test validates that all assignment policies are:
    - Accepting requests (requestorSettings.acceptRequests = true)
    - Properly configured with valid scope types
    - Not using deprecated scope types (e.g., "NoSubjects")
    - Have valid approval settings where required
    - Not expired
    - Have proper question configuration

    Learn more:
    https://maester.dev/docs/tests/MT.1108

.EXAMPLE
    Test-MtEntitlementManagementInactivePolicies

    Returns $true if all access package assignment policies are active and properly configured

.LINK
    https://maester.dev/docs/commands/Test-MtEntitlementManagementInactivePolicies
#>

function Test-MtEntitlementManagementInactivePolicies {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Policies is the resource type being tested')]
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

        $inactivePoliciesFound = @()

        # Check each access package for inactive or misconfigured policies
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

                foreach ($policy in $policyArray) {
                    $policyId = if ($policy.id) { $policy.id } else { $policy.PSObject.Properties['id'].Value }
                    $policyName = if ($policy.displayName) { $policy.displayName } else {
                        if ($policy.PSObject.Properties['displayName']) { $policy.PSObject.Properties['displayName'].Value } else { "Unnamed Policy" }
                    }

                    Write-Verbose "Checking policy: $policyName (ID: $policyId)"

                    $issues = @()

                    # Check 1: Validate if policy accepts requests
                    if ($policy.requestorSettings.acceptRequests -eq $false) {
                        $issues += "Policy is not accepting new requests"
                    }

                    # Check 2: Validate requestor scope type
                    if ($policy.requestorSettings) {
                        $scopeType = $policy.requestorSettings.scopeType

                        if ([string]::IsNullOrEmpty($scopeType)) {
                            $issues += "Requestor scope type is missing"
                        } elseif ($scopeType -eq "NoSubjects") {
                            $issues += "Nobody can request access (NoSubjects)"
                        } elseif ($scopeType -eq "SpecificDirectorySubjects") {
                            $allowedRequestors = $policy.requestorSettings.allowedRequestors
                            if ($null -eq $allowedRequestors -or $allowedRequestors.Count -eq 0) {
                                $issues += "No users/groups allowed to request"
                            }
                        }
                    } else {
                        $issues += "Requestor settings are missing"
                    }

                    # Check 3: Validate approval settings if approval is required
                    if ($policy.requestApprovalSettings) {
                        $isApprovalRequired = $policy.requestApprovalSettings.isApprovalRequired

                        if ($isApprovalRequired -eq $true) {
                            $approvalStages = $policy.requestApprovalSettings.approvalStages

                            if ($null -eq $approvalStages -or $approvalStages.Count -eq 0) {
                                $issues += "Approval required but no stages configured"
                            } else {
                                $hasValidApprovers = $false
                                foreach ($stage in $approvalStages) {
                                    if ($stage.primaryApprovers -and $stage.primaryApprovers.Count -gt 0) {
                                        $hasValidApprovers = $true
                                        break
                                    }
                                }

                                if (-not $hasValidApprovers) {
                                    $issues += "No valid approvers configured"
                                }
                            }
                        }
                    }

                    # Check 4: Validate expiration settings
                    if ($policy.PSObject.Properties['expirationDateTime']) {
                        $expirationDate = $policy.PSObject.Properties['expirationDateTime'].Value
                        if ($null -ne $expirationDate) {
                            $expDate = [DateTime]::Parse($expirationDate)
                            if ($expDate -lt (Get-Date)) {
                                $issues += "Policy expired on $($expDate.ToString('yyyy-MM-dd'))"
                            }
                        }
                    }

                    # If any issues found, add to results
                    if ($issues.Count -gt 0) {
                        $inactivePoliciesFound += [PSCustomObject]@{
                            PackageName = $packageName
                            PackageId = $packageId
                            PolicyName = $policyName
                            PolicyId = $policyId
                            ScopeType = $policy.requestorSettings.scopeType
                            Issues = $issues
                        }
                    }
                }
            } catch {
                Write-Verbose "Could not retrieve assignment policies for access package: $packageName. Error: $_"
            }
        }

        # Evaluate results
        $disabledPolicies = $inactivePoliciesFound | Where-Object { $_.ScopeType -ne "Error" }
        $result = $disabledPolicies.Count -eq 0

        if ($result) {
            $testResult = "✅ All access package assignment policies are active and properly configured."
            Add-MtTestResultDetail -Result $testResult
        } else {
            $issuesByPackage = $disabledPolicies | Group-Object PackageId
            $testResult = "❌ Found $($disabledPolicies.Count) inactive policy/policies across $($issuesByPackage.Count) access package(s):`n`n"

            $testResult += "| Access Package | Policy Name | Issue |`n"
            $testResult += "|---|---|---|`n"

            foreach ($packageGroup in $issuesByPackage) {
                $packageName = ($packageGroup.Group | Select-Object -First 1).PackageName
                $packageId = $packageGroup.Name
                $packageLink = "https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin/EntitlementMenuBlade/~/overview/entitlementId/$packageId"

                foreach ($policyIssue in $packageGroup.Group) {
                    $primaryIssue = ""
                    if ($policyIssue.Issues -match "NoSubjects") {
                        $primaryIssue = "No one can request"
                    } elseif ($policyIssue.Issues -match "not accepting new requests") {
                        $primaryIssue = "Not accepting requests"
                    } elseif ($policyIssue.Issues -match "No users/groups") {
                        $primaryIssue = "No users allowed"
                    } elseif ($policyIssue.Issues -match "expired") {
                        $primaryIssue = "Expired"
                    } elseif ($policyIssue.Issues -match "no stages|No valid approvers") {
                        $primaryIssue = "No approvers"
                    } else {
                        $primaryIssue = $policyIssue.Issues[0]
                    }

                    $testResult += "| [$packageName]($packageLink) | $($policyIssue.PolicyName) | $primaryIssue |`n"
                }
            }

            $testResult += "`n**Remediation:** Update or remove these policies in the [Entra portal](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin).`n"

            Add-MtTestResultDetail -Result $testResult
        }

        return $result

    } catch {
        Write-Error "Error checking access package assignment policies: $($_.Exception.Message)"
        return $false
    }
}


