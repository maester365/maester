function Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidationCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status if the Enable shell tasks arguments validation setting that validates argument parameters for built-in shell tasks to check for inputs that can inject commands into scripts.
    The check ensures that the shell correctly executes characters like semicolons, quotes, and parentheses.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#shellTasksValidation
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidationCompliance
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
    Write-Verbose "Running Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation"


    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        return $null
    }

    $result = $settings.enableShellTasksArgsSanitizing

    if ($result) {
        $resultMarkdown = "Argument parameters for built-in shell tasks are validated to check for inputs that can inject commands into scripts."
    } else {
        $resultMarkdown = "Argument parameters for built-in shell tasks may inject commands into scripts."
    }


    return $result

}
