function Test-AzdoFeedbackCollectionCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status if Azure DevOps is collecting customer feedback to the product team.

    https://aka.ms/ADOPrivacyPolicy
    https://learn.microsoft.com/en-us/azure/devops/organizations/security/data-protection?view=azure-devops#managing-privacy-policies-for-admins-to-control-user-feedback-collection
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoFeedbackCollectionCompliance
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
    Write-Verbose "Running Test-AzdoFeedbackCollection"


    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Privacy' -Force
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.AllowFeedbackCollection'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your Azure DevOps tenant allows feedback collection."
    } else {
        $resultMarkdown = "You should have confidence that we're handling your data appropriately and for legitimate uses. Part of that assurance involves carefully restricting usage."
    }


    return $result

}
