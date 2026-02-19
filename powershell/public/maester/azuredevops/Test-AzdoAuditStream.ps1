<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Sends auditing data to Security Incident and Event Management (SIEM) tools and opens new possibilities,
    such as the ability to trigger alerts for specific events, create views on auditing data, and perform
    anomaly detection. Setting up a stream also allows you to store more than 90-days of auditing data,
    which is the maximum amount of data that Azure DevOps keeps for your organizations.

    https://learn.microsoft.com/en-us/azure/devops/organizations/audit/auditing-streaming?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoAuditStream
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoAuditStream
#>

function Test-AzdoAuditStream {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
        break
    }

    $AuditStreams = Get-ADOPSAuditStreams

    if ($AuditStreams) {
        if ('Enabled' -in $AuditStreams.status) {
            $resultMarkdown = "Well done. Audit logs have been configured for long-term storage and purge protection."
            $result = $true
        } else {
            $resultMarkdown = "Audit Streams have been configured for long-term storage and purge protection but is not enabled."
            $result = $false
        }
    } else {
        $resultMarkdown = "Audit Streams have not been configured for long-term storage and purge protection."
        $result = $false
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
