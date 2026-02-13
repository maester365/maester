<#
 .Synopsis
  Checks if all Protected Actions Authentication Contexts are referenced by a conditional access policy.

 .Description
    Protected Actions allow organizations to require step-up authentication for sensitive operations by
    assigning Authentication Contexts to those actions. However, if an Authentication Context is not
    referenced in any Conditional Access policy, the protected action is not effectively protected.

    This test verifies that all Authentication Contexts used by Protected Actions are properly referenced
    in at least one Conditional Access policy.

  Learn more:
  https://learn.microsoft.com/entra/identity/role-based-access-control/protected-actions-overview

 .Example
  Test-MtCaAuthContextProtectedActionsExist

.LINK
    https://maester.dev/docs/commands/Test-MtCaAuthContextProtectedActionsExist
#>
function Test-MtCaAuthContextProtectedActionsExist {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plural.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if (-not $pim) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
    }

    try {
        # Get all authentication contexts
        $authContexts = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/authenticationContextClassReferences' -ApiVersion beta

        if (-not $authContexts -or ($authContexts | Measure-Object).Count -eq 0) {
            $testResult = 'No Authentication Contexts are configured in the tenant.'
            Add-MtTestResultDetail -Result $testResult
            return $true
        }

        # Get Protected Actions with authentication contexts
        # Protected Actions are accessed through roleManagement/directory/resourceNamespaces
        try {
            $resourceNamespaces = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/resourceNamespaces' -ApiVersion beta -ErrorAction SilentlyContinue
            Write-Verbose "Found $($resourceNamespaces.Count) resource namespaces"
        } catch {
            Write-Verbose "Could not retrieve resource namespaces: $_"
            $resourceNamespaces = @()
        }

        # Collect all auth context IDs that are used in protected actions
        $authContextsInProtectedActions = [System.Collections.Generic.HashSet[string]]::new()

        # Check each resource namespace for protected actions with authentication contexts
        if ($resourceNamespaces) {
            $namespaceCount = 0
            foreach ($namespace in $resourceNamespaces) {
                $namespaceCount++
                try {
                    # Get resource actions for this namespace
                    $resourceActions = Invoke-MtGraphRequest -RelativeUri "roleManagement/directory/resourceNamespaces/$($namespace.id)/resourceActions" -ApiVersion beta -ErrorAction SilentlyContinue
                    if ($resourceActions) {
                        Write-Verbose "Namespace $namespaceCount/$($resourceNamespaces.Count) ($($namespace.id)): Found $($resourceActions.Count) resource actions"
                        foreach ($action in $resourceActions) {
                            # Debug: Log all properties of the first few actions to understand structure
                            if ($namespaceCount -le 3 -and $resourceActions.IndexOf($action) -le 2) {
                                Write-Verbose "Sample action properties: $($action | ConvertTo-Json -Depth 2 -Compress)"
                            }
                            
                            # Check if this action has an authentication context requirement
                            # Try multiple possible property names
                            $authContextId = $null
                            if ($action.authenticationContextId) {
                                $authContextId = $action.authenticationContextId
                            } elseif ($action.authenticationContext) {
                                $authContextId = $action.authenticationContext
                            } elseif ($action.authContext) {
                                $authContextId = $action.authContext
                            } elseif ($action.PSObject.Properties['authenticationContextId']) {
                                $authContextId = $action.PSObject.Properties['authenticationContextId'].Value
                            }
                            
                            if ($authContextId) {
                                Write-Verbose "Found protected action '$($action.name)' with authentication context: $authContextId"
                                [void]$authContextsInProtectedActions.Add($authContextId)
                            }
                        }
                    }
                } catch {
                    Write-Verbose "Could not retrieve resource actions for namespace $($namespace.id): $_"
                }
            }
        }

        Write-Verbose "Total authentication contexts found in protected actions: $($authContextsInProtectedActions.Count)"

        # Get all enabled conditional access policies
        $caPolicies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }

        # Collect all auth context IDs referenced in CA policies
        $authContextsInCAPolicies = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($policy in $caPolicies) {
            if ($policy.conditions.applications.includeAuthenticationContextClassReferences) {
                foreach ($context in $policy.conditions.applications.includeAuthenticationContextClassReferences) {
                    [void]$authContextsInCAPolicies.Add($context)
                }
            }
        }

        # Check for auth contexts that are used in protected actions but not in CA policies
        $unprotectedContexts = [System.Collections.Generic.List[object]]::new()

        foreach ($id in $authContextsInProtectedActions) {
            if (-not $authContextsInCAPolicies.Contains($id)) {
                $ctx = $authContexts | Where-Object { $_.id -eq $id } | Select-Object -First 1
                $unprotectedContexts.Add(@{
                    Id = $id
                    DisplayName = if ($ctx) { $ctx.displayName } else { '(Deleted or not found)' }
                    Description = if ($ctx) { $ctx.description } else { '' }
                    IsAvailable = if ($ctx) { $ctx.isAvailable } else { $null }
                })
            }
        }

        # Determine result
        $result = $unprotectedContexts.Count -eq 0

        if ($result) {
            if ($authContextsInProtectedActions.Count -eq 0) {
                $testResult = 'No Authentication Contexts are configured for Protected Actions in this tenant.'
            } else {
                $testResult = "All Authentication Contexts used in Protected Actions are properly referenced in Conditional Access policies.`n`n"
                $testResult += "**Protected Action Auth Contexts with CA policies:**`n`n"
                foreach ($authContext in $authContexts) {
                    if ($authContextsInProtectedActions.Contains($authContext.id)) {
                        $testResult += "- $($authContext.displayName) ($($authContext.id))`n"
                    }
                }
            }
        } else {
            $testResult = "The following Authentication Contexts are used in Protected Actions but are not referenced by any Conditional Access policy:`n`n"
            $testResult += "| Authentication Context | ID | Description |`n"
            $testResult += "| --- | --- | --- |`n"
            foreach ($context in $unprotectedContexts) {
                $displayName = if ($context.DisplayName) { $context.DisplayName } else { "(No name)" }
                $description = if ($context.Description) { $context.Description } else { "(No description)" }
                $testResult += "| $displayName | $($context.Id) | $description |`n"
            }
            $testResult += "`n`n⚠️ **Warning**: These Protected Actions are not effectively protected because their Authentication Contexts are not referenced by any Conditional Access policy.`n"
        }

        Add-MtTestResultDetail -Result $testResult
        return $result

    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
