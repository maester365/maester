function Test-AzdoAllowRequestAccessTokenCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status of the 'Request Access' policy in Azure DevOps to prevent users from requesting access to your organization or projects.
    When this policy is enabled, users can request access, and administrators receive email notifications for review and approval.
    Disabling the policy stops these requests and notifications, helping you control access more tightly.

    https://go.microsoft.com/fwlink/?linkid=2113172
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoAllowRequestAccessTokenCompliance
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
    Write-Verbose "Running Test-AzdoAllowRequestAccessToken"


    $UserPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User' -Force
    $Policy = $UserPolicies.policy | where-object -property name -eq 'Policy.AllowRequestAccessToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "When enabled, this policy allows users to request access, triggering email notifications to administrators for review and approval."
    } else {
        $resultMarkdown = "Disabling the policy stops these requests and notifications."
    }


    return $result

}
