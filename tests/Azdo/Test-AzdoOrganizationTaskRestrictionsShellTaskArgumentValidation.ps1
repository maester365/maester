function Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enableShellTasksArgsSanitizing

    if ($result) {
        $resultMarkdown = "Well done. Argument parameters for built-in shell tasks are validated to check for inputs that can inject commands into scripts."
    }
    else {
        $resultMarkdown = "Argument parameters for built-in shell tasks may inject commands into scripts."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown   -Severity 'Critical'

    return $result
}
