function Test-AzdoLogAuditEventCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if auditing of events is configured.

    https://learn.microsoft.com/en-us/azure/devops/organizations/audit/azure-devops-auditing?view=azure-devops&tabs=preview-page#enable-and-disable-auditing
    https://learn.microsoft.com/en-us/azure/devops/organizations/audit/azure-devops-auditing?view=azure-devops&tabs=preview-page#review-audit-log
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoLogAuditEventCompliance
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
    Write-Verbose "Running Test-AzdoLogAuditEvent"


    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.LogAuditEvents'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant has auditing enabled, tracking events such as permission changes, deleted resources, log access and downloads with many other types of changes."
    } else {
        $resultMarkdown = "Your tenant does not have logging enabled for Azure DevOps"
    }


    return $result

}
