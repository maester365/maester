<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of the 'Request Access' policy in Azure DevOps to prevent users from requesting access to your organization or projects.
    When this policy is enabled, users can request access, and administrators receive email notifications for review and approval.
    Disabling the policy stops these requests and notifications, helping you control access more tightly.

    https://go.microsoft.com/fwlink/?linkid=2113172

.EXAMPLE
    ```
    Test-AzdoAllowRequestAccessToken
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoAllowRequestAccessToken
#>

function Test-AzdoAllowRequestAccessToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $UserPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User' -Force
    $Policy = $UserPolicies.policy | where-object -property name -eq 'Policy.AllowRequestAccessToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "When enabled, this policy allows users to request access, triggering email notifications to administrators for review and approval."
    } else {
        $resultMarkdown = "Disabling the policy stops these requests and notifications."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
