function Test-AzdoAuditStreams {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $AuditStreams = Get-ADOPSAuditStreams
    
    if ($AuditStreams) {
        if ('Enabled' -in $AuditStreams.status) {
            $resultMarkdown = "Well done. Audit logs have been configured for long-term storage and purge protection."
            $result = $true
        }
        else {
            $resultMarkdown = "Audit Streams have been configured for long-term storage and purge protection but is not enabled."
            $result = $false
        }
    }
    else {
        $resultMarkdown = "Audit Streams have not been configured for long-term storage and purge protection."
        $result = $false
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'Critical'

    return $result
}
