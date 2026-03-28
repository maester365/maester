<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status if Azure DevOps is collecting customer feedback to the product team.

    https://aka.ms/ADOPrivacyPolicy
    https://learn.microsoft.com/en-us/azure/devops/organizations/security/data-protection?view=azure-devops#managing-privacy-policies-for-admins-to-control-user-feedback-collection

.EXAMPLE
    ```
    Test-AzdoFeedbackCollection
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoFeedbackCollection
#>

function Test-AzdoFeedbackCollection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Privacy' -Force
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.AllowFeedbackCollection'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your Azure DevOps tenant allows feedback collection."
    } else {
        $resultMarkdown = "You should have confidence that we're handling your data appropriately and for legitimate uses. Part of that assurance involves carefully restricting usage."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
