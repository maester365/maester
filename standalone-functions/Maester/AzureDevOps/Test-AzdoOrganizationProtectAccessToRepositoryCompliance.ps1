function Test-AzdoOrganizationProtectAccessToRepositoryCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if checks and approvals are applied when accessing repositories from YAML pipelines.
    Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#restrict-project-repository-and-service-connection-access
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationProtectAccessToRepositoryCompliance
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
    Write-Verbose "Running Test-AzdoOrganizationProtectAccessToRepository"


    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        return $null
    }

    $result = $settings.enforceReferencedRepoScopedToken

    if ($result) {
        $resultMarkdown = "Checks and approvals are applied when accessing repositories from YAML pipelines. Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline."
    } else {
        $resultMarkdown = "Checks and approvals are not applied when accessing repositories from YAML pipelines. Also, a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline is not generated."
    }


    return $result

}
