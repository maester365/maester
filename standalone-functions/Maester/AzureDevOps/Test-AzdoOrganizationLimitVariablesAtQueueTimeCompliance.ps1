function Test-AzdoOrganizationLimitVariablesAtQueueTimeCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if user defined variables are able to override system variables or variables not defined by the pipeline author.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#limit-variables-that-can-be-set-at-queue-time
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationLimitVariablesAtQueueTimeCompliance
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
    Write-Verbose "Running Test-AzdoOrganizationLimitVariablesAtQueueTime"


    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        return $null
    }

    $result = $settings.enforceSettableVar

    if ($result) {
        $resultMarkdown = "With this option enabled, only those variables that are explicitly marked as ""Settable at queue time"" can be set"
    } else {
        $auditEnforceSettableVar = $settings.auditEnforceSettableVar
        if ($auditEnforceSettableVar) {
            $resultMarkdown = "Auditing is configured, however usage is not restricted."
        } else {
            $resultMarkdown = "Users can define new variables not defined by pipeline author, and may override system variables."
        }
    }


    return $result

}
