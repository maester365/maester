function Test-AzdoOrganizationLimitVariablesAtQueueTime {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceSettableVar

    if ($result) {
        $resultMarkdown = "Well done. With this option enabled, only those variables that are explicitly marked as ""Settable at queue time"" can be set"
    }
    else {
        $auditEnforceSettableVar = (Get-ADOPSOrganizationPipelineSettings).auditEnforceSettableVar
        if ($auditEnforceSettableVar) {
            $resultMarkdown = "Auditing is configured, however usage is not restricted."
        }
        else {
            $resultMarkdown = "Users can define new variables not defined by pipeline author, and may override system variables."
        }
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
