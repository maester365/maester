function Test-AzdoEnforceAADConditionalAccessCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status of when you sign in to the web portal of a Microsoft Entra ID-backed organization,
    Microsoft Entra ID always performs validation for any Conditional Access Policies (CAPs) set by tenant administrators.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-conditional-access?view=azure-devops&tabs=preview-page
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoEnforceAADConditionalAccessCompliance
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
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Running Test-AzdoEnforceAADConditionalAccess"


    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.EnforceAADConditionalAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Microsoft Entra ID always performs validation for any Conditional Access Policies (CAPs) set by tenant administrators."
    } else {
        $resultMarkdown = "Your tenant should always perform validation for any Conditional Access Policies (CAPs) set by tenant administrators. "
    }


    return $result

}
