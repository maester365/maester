function Test-AzdoOrganizationCreationClassicReleasePipelineCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if classic release pipelines can be created.

    https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationCreationClassicReleasePipelineCompliance
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
    Write-Verbose "Running Test-AzdoOrganizationCreationClassicReleasePipeline"


    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        return $null
    }

    $result = $settings.disableClassicReleasePipelineCreation

    if (-not $result) {
        $resultMarkdown = "Classic release pipelines, task groups, and deployment groups can be created / imported."
    } else {
        $resultMarkdown = "No classic release pipelines, task groups, and deployment groups can be created / imported. Existing ones will continue to work."
    }


    return -not $result

}
