function Test-AzdoAuditStreamCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Sends auditing data to Security Incident and Event Management (SIEM) tools and opens new possibilities,
    such as the ability to trigger alerts for specific events, create views on auditing data, and perform
    anomaly detection. Setting up a stream also allows you to store more than 90-days of auditing data,
    which is the maximum amount of data that Azure DevOps keeps for your organizations.

    https://learn.microsoft.com/en-us/azure/devops/organizations/audit/auditing-streaming?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoAuditStreamCompliance
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
    Write-Verbose "Running Test-AzdoAuditStream"


    $AuditStreams = Get-ADOPSAuditStreams -ErrorAction SilentlyContinue

    if ($null -eq $AuditStreams) {
        $Message = "Audit Streams was not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Audit Streams](https://learn.microsoft.com/en-us/azure/devops/organizations/audit/auditing-streaming?view=azure-devops#prerequisites)"
        Write-Verbose $Message
        return $null
    } else {
        if ($AuditStreams) {
            if ('Enabled' -in $AuditStreams.status) {
                $resultMarkdown = "Audit logs have been configured for long-term storage and purge protection."
                $result = $true
            } else {
                $resultMarkdown = "Audit Streams have been configured for long-term storage and purge protection but is not enabled."
                $result = $false
            }
        } else {
            $resultMarkdown = "Audit Streams have not been configured for long-term storage and purge protection."
            $result = $false
        }


        return $result
    }


}
