function Test-AzdoDisablePATCreationCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if Personal Access Token creation is restricted at the organization level.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoDisablePATCreationCompliance
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
    Write-Verbose "Running Test-AzdoDisablePATCreation"


    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.DisablePATCreation'
    $result = $Policy.value
    if ($result) {
        $resultMarkdown = "Your organization has restricted Personal Access Token creation.`n`n"
        $resultMarkdown += "| Setting | Value |`n"
        $resultMarkdown += "| --- | --- |`n"
        $resultMarkdown += "| Allow list enabled | $($Policy.properties.isAllowListEnabled) |`n"
        $resultMarkdown += "| Packaging scope only | $($Policy.properties.isPackagingScopeEnabled) |`n"
        if ($Policy.properties.isAllowListEnabled -and $Policy.properties.allowedUsersAndGroupObjectIds.Count -gt 0) {
            $resultMarkdown += "`n| Display Name | Object ID |`n"
            $resultMarkdown += "| --- | --- |`n"
            $Policy.properties.allowedUsersAndGroupObjectIds | ForEach-Object {
                $resultMarkdown += "| $($_.displayName) | $($_.objectId) |`n"
            }
        }
    } else {
        $resultMarkdown = "Your organization has not restricted Personal Access Token creation."
    }


    return $result

}
