function Test-AzdoOrganizationOwnerCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if the Azure DevOps Organization owner is a individual or a service/admin account.
    Returns a true boolean if the users matches adm|admin|btg|svc|service.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-organization-ownership?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationOwnerCompliance
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
    Write-Verbose "Running Test-AzdoOrganizationOwner"


    $Data = Get-ADOPSOrganizationAdminOverview
    if ($data.'ms.vss-admin-web.organization-admin-overview-delay-load-data-provider'.exceptionType -eq 'AadGraphException') {
        $resultMarkdown = "Workload identities cannot fetch Organization Owner."
        $result = $null
    } else {
        $currentOwner = $data.'ms.vss-admin-web.organization-admin-overview-delay-load-data-provider'.currentOwner
        if ($currentOwner.email -match '(?i)(adm|admin|btg|svc|service)') {
            $result = $true
        } else {
            $result = $false
        }
        $markdown = "| Name | Id | E-mail |`n"
        $markdown += "| --- | --- | --- |`n"
        $markdown += "| $($currentOwner.name) | $($currentOwner.id) | $($currentOwner.email) |`n"
    }
    return $result

}
